import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:libavif/libavif.dart';

import 'avif_image_provider.dart';
import 'avif_image_source.dart';

/// Decodes one exact AVIF asset into a Flutter image.
@immutable
final class AvifAssetImage extends AvifImageProvider<AvifAssetImageKey> {
  AvifAssetImage(
    this.assetName, {
    this.bundle,
    super.scale,
    super.cacheWidth,
    super.cacheHeight,
    super.options,
  });

  final String assetName;
  final AssetBundle? bundle;
  @override
  Future<AvifAssetImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AvifAssetImageKey>(
      AvifAssetImageKey(
        bundle: bundle ?? configuration.bundle ?? rootBundle,
        assetName: assetName,
        scale: scale,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        options: options,
      ),
    );
  }

  @override
  AvifImageSource loadAvifSource(AvifAssetImageKey key) =>
      AvifImageSource(bytes: _load(key));

  Future<Uint8List> _load(AvifAssetImageKey key) async {
    ByteData data;
    try {
      data = await key.bundle.load(key.assetName);
    } on FlutterError {
      PaintingBinding.instance.imageCache.evict(key);
      rethrow;
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  String describeAvifSource(AvifAssetImageKey key) => key.assetName;

  @override
  String toString() => 'AvifAssetImage($assetName, scale: $scale)';
}

/// Cache key resolved by [AvifAssetImage].
@immutable
final class AvifAssetImageKey {
  const AvifAssetImageKey({
    required this.bundle,
    required this.assetName,
    required this.scale,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.options,
  });

  final AssetBundle bundle;
  final String assetName;
  final double scale;
  final int? cacheWidth;
  final int? cacheHeight;
  final AvifDecodeOptions options;

  @override
  bool operator ==(Object other) =>
      other is AvifAssetImageKey &&
      other.bundle == bundle &&
      other.assetName == assetName &&
      other.scale == scale &&
      other.cacheWidth == cacheWidth &&
      other.cacheHeight == cacheHeight &&
      other.options == options;

  @override
  int get hashCode =>
      Object.hash(bundle, assetName, scale, cacheWidth, cacheHeight, options);

  @override
  String toString() =>
      'AvifAssetImageKey(bundle: $bundle, assetName: $assetName, scale: $scale)';
}
