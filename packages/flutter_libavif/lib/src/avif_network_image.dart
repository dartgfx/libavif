import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:libavif/libavif.dart';

import 'avif_image_provider.dart';
import 'avif_image_source.dart';

/// Fetches and decodes an AVIF image over HTTP.
@immutable
final class AvifNetworkImage extends AvifImageProvider<AvifNetworkImage> {
  AvifNetworkImage(
    this.url, {
    super.scale,
    Map<String, String>? headers,
    this.client,
    super.cacheWidth,
    super.cacheHeight,
    super.options,
  }) : headers = Map.unmodifiable(headers ?? const <String, String>{});

  final String url;
  final Map<String, String> headers;

  /// Optional client used for this provider. When omitted, a shared client is
  /// used.
  final HttpClient? client;
  static final HttpClient _client = HttpClient()..autoUncompress = true;

  @override
  Future<AvifNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<AvifNetworkImage>(this);

  @override
  AvifImageSource loadAvifSource(AvifNetworkImage key) {
    assert(key == this);
    final progress = StreamController<ImageChunkEvent>();
    final result = Completer<Uint8List>();
    HttpClientRequest? request;
    StreamSubscription<List<int>>? responseSubscription;
    Completer<void>? responseDone;
    var cancelled = false;

    void fail(Object error, StackTrace stack) {
      if (!result.isCompleted) result.completeError(error, stack);
      if (!progress.isClosed) progress.close();
      PaintingBinding.instance.imageCache.evict(key);
    }

    unawaited(
      Future<void>(() async {
        final uri = Uri.base.resolve(key.url);
        request = await (key.client ?? _client).getUrl(uri);
        if (cancelled) {
          request!.abort();
          return;
        }
        key.headers.forEach(request!.headers.add);
        final response = await request!.close();
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<List<int>>(<int>[]);
          throw HttpException(
            'HTTP ${response.statusCode} while loading AVIF image',
            uri: uri,
          );
        }
        if (response.contentLength > key.options.maxInputBytes) {
          await response.listen((_) {}).cancel();
          throw AvifException(
            AvifErrorCode.limitExceeded,
            'AVIF response declares ${response.contentLength} bytes, '
            'exceeding the configured ${key.options.maxInputBytes}-byte limit.',
          );
        }

        final builder = BytesBuilder(copy: false);
        var length = 0;
        final done = Completer<void>();
        responseDone = done;
        responseSubscription = response.listen(
          (chunk) {
            length += chunk.length;
            if (length > key.options.maxInputBytes) {
              responseSubscription?.cancel();
              done.completeError(
                AvifException(
                  AvifErrorCode.limitExceeded,
                  'AVIF download exceeds the configured '
                  '${key.options.maxInputBytes}-byte limit.',
                ),
              );
              return;
            }
            builder.add(chunk);
            progress.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: length,
                expectedTotalBytes: response.contentLength < 0
                    ? null
                    : response.contentLength,
              ),
            );
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stack) {
            if (!done.isCompleted) done.completeError(error, stack);
          },
          cancelOnError: true,
        );
        await done.future;
        if (!cancelled && !result.isCompleted) {
          result.complete(builder.takeBytes());
        }
        if (!progress.isClosed) await progress.close();
      }).catchError(fail),
    );

    return AvifImageSource(
      bytes: result.future,
      chunkEvents: progress.stream,
      cancel: () {
        if (cancelled) return;
        cancelled = true;
        request?.abort();
        responseSubscription?.cancel();
        final done = responseDone;
        if (done != null && !done.isCompleted) {
          done.completeError(
            const AvifException(
              AvifErrorCode.cancelled,
              'AVIF network load cancelled.',
            ),
          );
        }
        if (!result.isCompleted) {
          result.completeError(
            const AvifException(
              AvifErrorCode.cancelled,
              'AVIF network load cancelled.',
            ),
          );
        }
        if (!progress.isClosed) progress.close();
      },
    );
  }

  @override
  String describeAvifSource(AvifNetworkImage key) => key.url;

  @override
  bool operator ==(Object other) =>
      other is AvifNetworkImage &&
      other.url == url &&
      other.scale == scale &&
      mapEquals(other.headers, headers) &&
      identical(other.client, client) &&
      other.cacheWidth == cacheWidth &&
      other.cacheHeight == cacheHeight &&
      other.options == options;

  @override
  int get hashCode => Object.hash(
    url,
    scale,
    Object.hashAllUnordered(
      headers.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    client,
    cacheWidth,
    cacheHeight,
    options,
  );

  @override
  String toString() => 'AvifNetworkImage($url, scale: $scale)';
}
