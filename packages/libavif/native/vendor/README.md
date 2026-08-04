# Vendored native source

`libavif/` contains the build, headers, and library sources from libavif
1.4.2, released at https://github.com/AOMediaCodec/libavif/releases/tag/v1.4.2.

Only the decoder library sources are retained. Applications, tests, and
unrelated third-party source trees are excluded.

`libavif/ext/dav1d/` contains dav1d 1.5.4 from tag `1.5.4`, commit
`54706fc6bc0cdecab7e9593974a4039cc038fca7`. libavif's local-codec build owns
its static Meson/Ninja build for the target selected by the Dart native-assets
hook. The upstream dav1d BSD-2-Clause license is retained as
`libavif/ext/dav1d/COPYING`.
