import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_libavif/flutter_libavif.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  test('memory provider decodes pixels at the requested cache size', () async {
    final provider = AvifMemoryImage(whiteAvif, cacheWidth: 2, cacheHeight: 3);
    final info = await _resolve(provider);
    try {
      expect((info.image.width, info.image.height), (2, 3));
      final pixels = await info.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(pixels, isNotNull);
      expect(pixels!.lengthInBytes, 2 * 3 * 4);
      expect(pixels.buffer.asUint8List().take(4), [253, 253, 253, 255]);
    } finally {
      info.dispose();
    }
  });

  test('decode settings participate in provider cache identity', () {
    final bytes = whiteAvif;

    expect(
      AvifMemoryImage(bytes, cacheWidth: 64),
      isNot(AvifMemoryImage(bytes, cacheWidth: 128)),
    );
    expect(
      AvifMemoryImage(bytes, options: const AvifDecodeOptions(maxPixels: 1024)),
      AvifMemoryImage(bytes, options: const AvifDecodeOptions(maxPixels: 1024)),
    );
  });

  testWidgets('memory provider delivers animated frames in order', (
    tester,
  ) async {
    final provider = AvifMemoryImage(animatedAvif, cacheWidth: 30);
    final stream = provider.resolve(ImageConfiguration.empty);
    final frames = <ImageInfo>[];
    final errors = <Object>[];
    final listener = ImageStreamListener(
      (image, synchronousCall) => frames.add(image.clone()),
      onError: (Object error, StackTrace? stackTrace) => errors.add(error),
    );
    stream.addListener(listener);

    for (var attempt = 0; attempt < 40 && frames.length < 5; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
    stream.removeListener(listener);

    try {
      expect(errors, isEmpty);
      expect(frames, hasLength(greaterThanOrEqualTo(5)));
      expect(
        frames.take(5).map((frame) => (frame.image.width, frame.image.height)),
        everyElement((30, 30)),
      );
    } finally {
      for (final frame in frames) {
        frame.dispose();
      }
    }
  });
}

Future<ImageInfo> _resolve(ImageProvider<Object> provider) {
  final result = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (image, synchronousCall) {
      if (!result.isCompleted) result.complete(image.clone());
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return result.future;
}
