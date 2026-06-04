import 'dart:io';

import 'package:flutter/services.dart';

/// Mapbox native cannot read Flutter bundle paths directly on iOS.
/// Copy the asset to a temp file and return a `file://` URI for [StyleManager.addStyleModel].
Future<String> materializeMapboxAssetUri(String flutterAssetKey) async {
  final data = await rootBundle.load(flutterAssetKey);
  final safeName = flutterAssetKey.replaceAll('/', '_');
  final file = File('${Directory.systemTemp.path}/mapbox_$safeName');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.uri.toString();
}
