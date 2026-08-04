import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:libavif/libavif.dart';

import 'avif_image_source.dart';

void validateProviderArguments({
  required double scale,
  required int? cacheWidth,
  required int? cacheHeight,
}) {
  if (!scale.isFinite || scale <= 0) {
    throw ArgumentError.value(scale, 'scale', 'must be finite and positive');
  }
  if (cacheWidth != null && cacheWidth <= 0) {
    throw ArgumentError.value(cacheWidth, 'cacheWidth', 'must be positive');
  }
  if (cacheHeight != null && cacheHeight <= 0) {
    throw ArgumentError.value(cacheHeight, 'cacheHeight', 'must be positive');
  }
}

/// Schedules still and animated AVIF frames on Flutter's image stream.
final class AvifImageStreamCompleter extends ImageStreamCompleter {
  AvifImageStreamCompleter({
    required AvifImageSource source,
    required this.scale,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.options,
    required String debugLabel,
    this._informationCollector,
  }) : _sourceCancel = source.cancel,
       super() {
    this.debugLabel = debugLabel;
    final chunkEvents = source.chunkEvents;
    if (chunkEvents != null) {
      _chunkSubscription = chunkEvents.listen(
        reportImageChunkEvent,
        onError: _reportLoadError,
      );
    }
    source.bytes.then<void>(_prepareDecoder, onError: _reportLoadError);
  }

  final double scale;
  final int? cacheWidth;
  final int? cacheHeight;
  final AvifDecodeOptions options;
  final VoidCallback? _sourceCancel;
  final InformationCollector? _informationCollector;

  StreamSubscription<ImageChunkEvent>? _chunkSubscription;
  AvifSequenceOpenOperation? _openOperation;
  AvifSequenceDecoder? _decoder;
  _FlutterAvifFrame? _nextFrame;
  Timer? _timer;
  Duration? _shownTimestamp;
  Duration? _shownFrameDuration;
  var _frameCallbackScheduled = false;
  var _decodeInProgress = false;
  var _playsCompleted = 0;
  var _disposed = false;

  Future<void> _prepareDecoder(Uint8List bytes) async {
    try {
      await Avif.warmUp();
      if (!_disposed) _open(bytes);
    } catch (error, stack) {
      _reportDecodeError(error, stack);
    }
  }

  void _open(Uint8List bytes) {
    if (_disposed) return;
    final operation = AvifSequenceDecoder.startOpen(
      bytes,
      options: options,
      targetWidth: cacheWidth,
      targetHeight: cacheHeight,
      prefetchFirstFrame: true,
    );
    _openOperation = operation;
    operation.result.then<void>(
      _handleDecoderReady,
      onError: _reportDecodeError,
    );
  }

  void _handleDecoderReady(AvifSequenceDecoder decoder) {
    _openOperation = null;
    if (_disposed) {
      decoder.dispose();
      return;
    }
    _decoder = decoder;
    if (hasListeners) _decodeNextFrame();
  }

  Future<void> _decodeNextFrame() async {
    final decoder = _decoder;
    if (_disposed || !hasListeners || decoder == null || _decodeInProgress) {
      return;
    }
    _decodeInProgress = true;
    try {
      var frame = await decoder.nextFrame();
      if (frame == null) {
        if (!_shouldReplay(decoder.info.repetition)) {
          decoder.dispose();
          _decoder = null;
          return;
        }
        await decoder.reset();
        frame = await decoder.nextFrame();
        if (frame == null) {
          throw StateError('The AVIF decoder returned no frame after reset.');
        }
      }
      final flutterFrame = await _createFlutterFrame(frame);
      if (_disposed) {
        flutterFrame.image.dispose();
        return;
      }
      _nextFrame?.image.dispose();
      _nextFrame = flutterFrame;
      if (decoder.info.frameCount == 1) {
        if (hasListeners) {
          _nextFrame = null;
          setImage(
            ImageInfo(
              image: flutterFrame.image,
              scale: scale,
              debugLabel: debugLabel,
            ),
          );
        }
        decoder.dispose();
        _decoder = null;
      } else if (hasListeners) {
        _scheduleAppFrame();
      }
    } catch (error, stack) {
      if (!_disposed) {
        _decoder?.dispose();
        _decoder = null;
        _reportDecodeError(error, stack);
      }
    } finally {
      _decodeInProgress = false;
    }
  }

  bool _shouldReplay(AvifRepetition repetition) {
    _playsCompleted++;
    return switch (repetition.kind) {
      AvifRepetitionKind.infinite => true,
      AvifRepetitionKind.unknown => false,
      AvifRepetitionKind.finite => _playsCompleted < repetition.totalPlayCount!,
    };
  }

  void _scheduleAppFrame() {
    if (_disposed || _frameCallbackScheduled || !hasListeners) return;
    _frameCallbackScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_handleAppFrame);
  }

  void _handleAppFrame(Duration timestamp) {
    _frameCallbackScheduled = false;
    if (_disposed || !hasListeners || _nextFrame == null) return;
    final shownTimestamp = _shownTimestamp;
    final shownFrameDuration = _shownFrameDuration;
    if (shownTimestamp == null ||
        shownFrameDuration == null ||
        timestamp - shownTimestamp >= shownFrameDuration) {
      final frame = _nextFrame!;
      _nextFrame = null;
      _shownTimestamp = timestamp;
      _shownFrameDuration = frame.duration;
      setImage(
        ImageInfo(image: frame.image, scale: scale, debugLabel: debugLabel),
      );
      _decodeNextFrame();
      return;
    }
    final delay = shownFrameDuration - (timestamp - shownTimestamp);
    _timer = Timer(delay * timeDilation, _scheduleAppFrame);
  }

  @override
  void addListener(ImageStreamListener listener) {
    final resume = !hasListeners;
    super.addListener(listener);
    if (resume) {
      if (_nextFrame != null) {
        _scheduleAppFrame();
      } else {
        _decodeNextFrame();
      }
    }
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _reportLoadError(Object error, StackTrace stack) {
    if (_disposed) return;
    reportError(
      context: ErrorDescription('loading an AVIF image'),
      exception: error,
      stack: stack,
      informationCollector: _informationCollector,
      silent: true,
    );
  }

  void _reportDecodeError(Object error, StackTrace stack) {
    if (_disposed) return;
    reportError(
      context: ErrorDescription('decoding an AVIF image frame'),
      exception: error,
      stack: stack,
      informationCollector: _informationCollector,
      silent: true,
    );
  }

  @override
  void onDisposed() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _sourceCancel?.call();
    _openOperation?.cancel();
    _openOperation = null;
    _chunkSubscription?.cancel();
    _chunkSubscription = null;
    _nextFrame?.image.dispose();
    _nextFrame = null;
    _decoder?.dispose();
    _decoder = null;
    super.onDisposed();
  }
}

Future<_FlutterAvifFrame> _createFlutterFrame(AvifSequenceFrame frame) async {
  final image = frame.image;
  final buffer = await ui.ImmutableBuffer.fromUint8List(image.pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: image.width,
    height: image.height,
    rowBytes: image.rowBytes,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  try {
    final codec = await descriptor.instantiateCodec();
    try {
      final decoded = await codec.getNextFrame();
      return _FlutterAvifFrame(decoded.image, frame.duration);
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

final class _FlutterAvifFrame {
  const _FlutterAvifFrame(this.image, this.duration);

  final ui.Image image;
  final Duration duration;
}
