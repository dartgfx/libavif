# libavif for Dart and Flutter

Source-built AVIF decoding for Dart and Flutter, backed by libavif, dav1d, and
libyuv through Dart native assets. Applications do not download
repository-hosted prebuilt binaries.

## Packages

### [`libavif`](packages/libavif)

The native Dart decoder API. It supports still and animated AVIF, bounded
off-isolate decoding, cancellation, native scaling, decode safety limits, and
direct finalizer-owned pixel buffers.

[Package documentation](packages/libavif/README.md) ·
[pub.dev](https://pub.dev/packages/libavif)

### [`flutter_libavif`](packages/flutter_libavif)

Flutter `ImageProvider`s for assets, memory, files, and HTTP sources, including
animated AVIF playback through Flutter's standard `Image` widget.

[Package documentation](packages/flutter_libavif/README.md) ·
[pub.dev](https://pub.dev/packages/flutter_libavif)

Flutter applications normally depend on `flutter_libavif`; use `libavif`
directly for lower-level Dart or native image pipelines.

## Platform support

Android, iOS 13 or newer, Linux, macOS 11 or newer, and Windows are supported.
Web is not supported by these native-assets packages.

Native builds require Rust, CMake, Meson, and Ninja. x86 and x64 targets also
require NASM. libavif, dav1d, and libyuv are pinned and built from the vendored
source included with `libavif`.

## Development

Resolve the workspace dependencies, then run each package's tests:

```sh
dart pub get
(cd packages/libavif && dart test)
(cd packages/flutter_libavif && flutter test)
```

The Dart packages use the MIT license. Vendored native dependencies retain
their upstream licenses in the source tree.
