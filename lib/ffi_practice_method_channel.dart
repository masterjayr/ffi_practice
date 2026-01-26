import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ffi_practice_platform_interface.dart';

/// An implementation of [FfiPracticePlatform] that uses method channels.
class MethodChannelFfiPractice extends FfiPracticePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ffi_practice');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
