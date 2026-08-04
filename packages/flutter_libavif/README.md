# flutter_libavif

`flutter_libavif` supplies Flutter `ImageProvider`s backed by the source-built
native decoder in `package:libavif`.

```dart
Image(
  image: AvifAssetImage(
    'assets/cover.avif',
    cacheWidth: 1024,
  ),
)
```

Providers are available for asset, memory, file, and HTTP sources:

```dart
AvifAssetImage('assets/image.avif');
AvifMemoryImage(bytes);
AvifFileImage(File('/path/to/image.avif'));
AvifNetworkImage('https://example.com/image.avif');
```

Use Flutter's standard `Image` widget for layout, frame/error builders,
filtering, opacity, and accessibility. `cacheWidth` and `cacheHeight` are part
of each provider's cache key and are passed into native decode, avoiding a
full-resolution RGBA allocation and copy for thumbnails. Decoder thread,
dimension, pixel, and input-byte limits are configured with
`AvifDecodeOptions`.

Memory-backed image work is cancelled when its last Flutter image-stream
listener disappears. This keeps fast, recycled lists from retaining obsolete
queued decodes.

All providers display animated AVIF through Flutter's standard `Image` widget.
Frame timing and finite or infinite repetition come from the AVIF container.
Frame scheduling pauses when the stream has no listeners, and native sequence
resources are released when Flutter disposes the stream.

Applications that already own transport and caching can subclass
`AvifImageProvider` instead of surrendering those policies to the package:

```dart
final class CachedAvifImage extends AvifImageProvider<CachedAvifImage> {
  CachedAvifImage(this.url);

  final String url;

  @override
  Future<CachedAvifImage> obtainKey(ImageConfiguration configuration) async =>
      this;

  @override
  AvifImageSource loadAvifSource(CachedAvifImage key) => AvifImageSource(
    bytes: cacheOrDownload(key.url),
    chunkEvents: downloadProgress(key.url),
    cancel: () => cancelDownload(key.url),
  );
}
```

The source contract owns bytes, progress, and cancellation; the base provider
owns decode limits, native scaling, animated frame scheduling, diagnostics,
and disposal. The package imports native I/O providers and does not support
Flutter web.
