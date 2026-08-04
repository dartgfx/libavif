# libavif

`libavif` decodes AVIF images to premultiplied RGBA8 pixels from Dart. The
package builds libavif and its decoder from source through Dart native assets;
applications do not download or bundle repository-hosted prebuilt binaries.

The decoder backend is dav1d. The package does not link libaom or fall back to
a platform decoder.

```dart
final bytes = await File('image.avif').readAsBytes();
final frame = await Avif.decode(bytes);

print('${frame.width} × ${frame.height}');
print(frame.pixels); // Premultiplied RGBA8.
```

`Avif.decode` runs on a bounded pool of persistent native workers, keeping
codec CPU work off the calling isolate without creating an isolate for each
image. `Avif.startDecode` exposes cancellation for scrollable or otherwise
short-lived consumers. `Avif.decodeSync` is available for worker isolates and
command-line pipelines that already control scheduling. All three accept
`AvifDecodeOptions` with explicit thread, dimension, and pixel limits.

Use `targetWidth` and `targetHeight` to scale during native decode, before the
RGBA allocation and Dart copy:

```dart
final thumbnail = await Avif.decode(
  bytes,
  targetWidth: 256,
  targetHeight: 256,
);
```

Supplying one target dimension preserves aspect ratio. Supplying both requests
that exact size. Source dimensions and target dimensions remain subject to the
configured safety limits.

Animated and still images share the stateful sequence API:

```dart
final decoder = await AvifSequenceDecoder.open(bytes, targetWidth: 256);
try {
  print(decoder.info.frameCount);
  print(decoder.info.repetition);
  AvifSequenceFrame? frame;
  while ((frame = await decoder.nextFrame()) != null) {
    render(frame!.image.pixels, duration: frame.duration);
  }
  await decoder.reset(); // Rewind for another playback.
} finally {
  decoder.dispose();
}
```

The decoder preserves per-frame timing and finite, infinite, or unknown
repetition metadata. It owns its encoded input until `dispose`, serializes
frame operations through the bounded native worker pool, and supports
cancellation while opening. `Avif.decode` remains deliberately static-only so
callers cannot accidentally reduce an animation to its first frame.

Render transforms that would change the displayed image fail with
`AvifErrorCode.unsupported`. Web is not supported by this native-assets
package.

The vendored libavif source is version 1.4.2. The vendored dav1d source is
version 1.5.4. Both retain their BSD licenses in the vendored source tree.

Building requires Rust, CMake, Meson, and Ninja on the host. x86 and x64
targets additionally require NASM. Missing tools are reported as build errors;
the package never downloads source or substitutes another decoder. iOS targets
require iOS 13 or newer.
