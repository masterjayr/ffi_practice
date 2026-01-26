import 'dart:typed_data';

import 'package:ffi_practice/src/camera/qr_scanner_view.dart';
import 'package:ffi_practice/src/engine/qr_engine.dart';
import 'package:flutter/material.dart';

class FfiPractice {
  String? decodeQRCode(Uint8List grayBytes, int width, int height) {
    return QrEngine.decodeQRCode(grayBytes, width, height);
  }

  Widget buildQRScanner({required void Function(String result) onDetect}) {
    return QrScannerView(onDetect: onDetect);
  }
}
