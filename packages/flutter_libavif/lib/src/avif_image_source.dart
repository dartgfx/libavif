import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One independently managed source load for an AVIF image provider.
///
/// Custom providers can retain their own HTTP client, cache, retry, progress,
/// and authentication policy. [cancel] must be safe to call after [bytes] has
/// completed.
final class AvifImageSource {
  const AvifImageSource({required this.bytes, this.chunkEvents, this.cancel});

  final Future<Uint8List> bytes;
  final Stream<ImageChunkEvent>? chunkEvents;
  final VoidCallback? cancel;
}
