import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_libavif/flutter_libavif.dart';

void main() => runApp(const AvifExampleApp());

final Uint8List _sampleAvif = base64Decode(
  'AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUEAAADybWV0YQAAAAAAAAAo'
  'aGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAGxpYmF2aWYAAAAADnBpdG0AAAAA'
  'AAEAAAAeaWxvYwAAAABEAAABAAEAAAABAAABGgAAABcAAAAoaWluZgAAAAAAAQAA'
  'ABppbmZlAgAAAAABAABhdjAxQ29sb3IAAAAAamlwcnAAAABLaXBjbwAAABRpc3Bl'
  'AAAAAAAAAAEAAAABAAAAEHBpeGkAAAAAAwgICAAAAAxhdjFDgSAAAAAAABNjb2xy'
  'bmNseAABAA0ABoAAAAAXaXBtYQAAAAAAAAABAAEEAQKDBAAAAB9tZGF0EgAKBzgA'
  'BhAQ0GkyCh/wP///xAAAr3A=',
);

class AvifExampleApp extends StatelessWidget {
  const AvifExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('flutter_libavif example')),
      body: Center(
        child: Image(
          image: AvifMemoryImage(
            _sampleAvif,
            cacheWidth: 256,
            cacheHeight: 256,
          ),
          width: 256,
          height: 256,
          fit: BoxFit.contain,
          semanticLabel: 'AVIF decoded from memory',
        ),
      ),
    ),
  );
}
