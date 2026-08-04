import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:libavif/libavif.dart';

import 'avif_image_source.dart';
import 'image_loader.dart';

/// Base class for AVIF providers with application-owned source loading.
///
/// Subclasses implement [loadAvifSource] and retain full control of transport,
/// caching, retries, headers, progress reporting, and cancellation. This class
/// owns AVIF sequence decoding and Flutter frame scheduling.
abstract class AvifImageProvider<T extends Object> extends ImageProvider<T> {
  AvifImageProvider({
    this.scale = 1,
    this.cacheWidth,
    this.cacheHeight,
    this.options = const AvifDecodeOptions(),
  }) {
    validateProviderArguments(
      scale: scale,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  final double scale;
  final int? cacheWidth;
  final int? cacheHeight;
  final AvifDecodeOptions options;

  /// Starts loading encoded AVIF bytes for [key].
  AvifImageSource loadAvifSource(T key);

  /// Human-readable source label used in diagnostics.
  String describeAvifSource(T key) => key.toString();

  @override
  @nonVirtual
  ImageStreamCompleter loadImage(T key, ImageDecoderCallback decode) {
    late AvifImageSource source;
    try {
      source = loadAvifSource(key);
    } catch (error, stack) {
      source = AvifImageSource(bytes: Future<Uint8List>.error(error, stack));
    }
    return AvifImageStreamCompleter(
      source: source,
      scale: scale,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      options: options,
      debugLabel: describeAvifSource(key),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<Object>('Image provider', this),
        DiagnosticsProperty<Object>('Image key', key),
        ErrorDescription('AVIF source: ${describeAvifSource(key)}'),
      ],
    );
  }
}
