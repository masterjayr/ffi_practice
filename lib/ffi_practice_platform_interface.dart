import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ffi_practice_method_channel.dart';

abstract class FfiPracticePlatform extends PlatformInterface {
  /// Constructs a FfiPracticePlatform.
  FfiPracticePlatform() : super(token: _token);

  static final Object _token = Object();

  static FfiPracticePlatform _instance = MethodChannelFfiPractice();

  /// The default instance of [FfiPracticePlatform] to use.
  ///
  /// Defaults to [MethodChannelFfiPractice].
  static FfiPracticePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FfiPracticePlatform] when
  /// they register themselves.
  static set instance(FfiPracticePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
