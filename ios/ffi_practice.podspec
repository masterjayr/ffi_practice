Pod::Spec.new do |s|
  s.name             = 'ffi_practice'
  s.version          = '0.0.2'
  s.summary          = 'FFI QR Scanner'
  s.description      = 'FFI-based QR scanner using ZXing and OpenCV'
  s.homepage         = 'https://github.com/masterjayr/ffi_practice'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'You' => 'masterjayr97@email.com' }

  # 🔑 Download prebuilt binaries from GitHub Releases
  s.source = {
    :http => "https://github.com/masterjayr/ffi_practice/releases/download/v#{s.version}/ffi_practice_native-ios.zip"
  }

  s.ios.deployment_target = '12.0'

  # 🔑 Only vendored xcframework
  s.vendored_frameworks = 'ffi_practice_native.xcframework'

  # Required system frameworks
  s.frameworks = [
    'AVFoundation',
    'CoreVideo',
    'CoreMedia',
    'UIKit'
  ]

  # C++ config
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++'
  }
end