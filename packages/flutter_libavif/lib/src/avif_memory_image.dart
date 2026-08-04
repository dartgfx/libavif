import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'avif_image_provider.dart';
import 'avif_image_source.dart';

/// Decodes AVIF bytes into a Flutter image.
@immutable
final class AvifMemoryImage extends AvifImageProvider<AvifMemoryImage> {
  AvifMemoryImage(
    this.bytes, {
    super.scale,
    super.cacheWidth,
    super.cacheHeight,
    super.options,
  });

  /// The encoded AVIF bytes. Do not mutate this list after construction.
  final Uint8List bytes;
  @override
  Future<AvifMemoryImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AvifMemoryImage>(this);

  @override
  AvifImageSource loadAvifSource(AvifMemoryImage key) {
    assert(key == this);
    return AvifImageSource(bytes: SynchronousFuture<Uint8List>(bytes));
  }

  @override
  String describeAvifSource(AvifMemoryImage key) =>
      'AvifMemoryImage(${describeIdentity(bytes)})';

  @override
  bool operator ==(Object other) =>
      other is AvifMemoryImage &&
      other.bytes == bytes &&
      other.scale == scale &&
      other.cacheWidth == cacheWidth &&
      other.cacheHeight == cacheHeight &&
      other.options == options;

  @override
  int get hashCode =>
      Object.hash(bytes, scale, cacheWidth, cacheHeight, options);

  @override
  String toString() =>
      'AvifMemoryImage(${describeIdentity(bytes)}, scale: $scale)';
}
