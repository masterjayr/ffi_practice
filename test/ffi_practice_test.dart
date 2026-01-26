import 'package:flutter_test/flutter_test.dart';
import 'package:ffi_practice/ffi_practice_platform_interface.dart';
import 'package:ffi_practice/ffi_practice_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFfiPracticePlatform
    with MockPlatformInterfaceMixin
    implements FfiPracticePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FfiPracticePlatform initialPlatform = FfiPracticePlatform.instance;

  test('$MethodChannelFfiPractice is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFfiPractice>());
  });

  test('getPlatformVersion', () async {
    MockFfiPracticePlatform fakePlatform = MockFfiPracticePlatform();
    FfiPracticePlatform.instance = fakePlatform;
  });
}
