import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Renders the widget under [key]'s [RepaintBoundary] to PNG bytes, or null when
/// the boundary isn't laid out yet. Overridden in tests.
typedef CaptureImage = Future<Uint8List?> Function(GlobalKey key);

final captureImageProvider = Provider<CaptureImage>((ref) => _captureBoundary);

Future<Uint8List?> _captureBoundary(GlobalKey key) async {
  final object = key.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  final image = await object.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// Opens the OS share sheet with [bytes] as a PNG file (same sheet the roast
/// uses, but a file instead of text). Overridden in tests.
typedef ShareImage = Future<void> Function(Uint8List bytes, {required String name});

final shareImageProvider = Provider<ShareImage>(
  (ref) => (bytes, {required name}) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
      fileNameOverrides: [name],
    ),
  ),
);
