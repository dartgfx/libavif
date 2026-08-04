import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:libavif/libavif.dart';

import 'avif_image_provider.dart';
import 'avif_image_source.dart';

/// Decodes an AVIF file into a Flutter image.
@immutable
final class AvifFileImage extends AvifImageProvider<AvifFileImage> {
  AvifFileImage(
    this.file, {
    super.scale,
    super.cacheWidth,
    super.cacheHeight,
    super.options,
  });

  final File file;
  @override
  Future<AvifFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AvifFileImage>(this);

  @override
  AvifImageSource loadAvifSource(AvifFileImage key) {
    assert(key == this);
    return AvifImageSource(bytes: _load(key));
  }

  Future<Uint8List> _load(AvifFileImage key) async {
    final length = await key.file.length();
    if (length > key.options.maxInputBytes) {
      throw AvifException(
        AvifErrorCode.limitExceeded,
        'AVIF file is $length bytes, exceeding the configured '
        '${key.options.maxInputBytes}-byte limit.',
      );
    }
    final bytes = await key.file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('${key.file.path} is empty and cannot be decoded.');
    }
    return bytes;
  }

  @override
  String describeAvifSource(AvifFileImage key) => key.file.path;

  @override
  bool operator ==(Object other) =>
      other is AvifFileImage &&
      other.file.path == file.path &&
      other.scale == scale &&
      other.cacheWidth == cacheWidth &&
      other.cacheHeight == cacheHeight &&
      other.options == options;

  @override
  int get hashCode =>
      Object.hash(file.path, scale, cacheWidth, cacheHeight, options);

  @override
  String toString() => 'AvifFileImage(${file.path}, scale: $scale)';
}
