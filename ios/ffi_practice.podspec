Pod::Spec.new do |s|
    s.name             = 'ffi_practice'
    s.version          = '0.0.1'
    s.summary          = 'FFI QR Scanner'
    s.description      = <<-DESC
  FFI-based QR scanner using ZXing and OpenCV
                         DESC
    s.homepage         = 'https://github.com/yourname/ffi_practice'
    s.license          = { :file => '../LICENSE' }
    s.author           = { 'You' => 'you@email.com' }
  
    s.source           = { :path => '.' }
  
    s.ios.deployment_target = '12.0'
  
    # 👇 C++ source
    s.source_files = [
    'Classes/**/*.{h,mm}',
    '../native/src/**/*.{cpp}',
    '../native/include/**/*.{h}'
    ]
  
    # 👇 Make headers visible
    s.public_header_files = [
    '../native/include/**/*.h'
    ]

  
    # 👇 Link ZXing + OpenCV frameworks
    s.vendored_frameworks = [
      'Frameworks/ZXing.framework',
      'Frameworks/opencv2.framework'
    ]
  
    # 👇 Required system frameworks
    s.frameworks = [
      'AVFoundation',
      'CoreVideo',
      'CoreMedia',
      'UIKit'
    ]
  
    # 👇 Required C++ flags
    s.pod_target_xcconfig = {
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
      'CLANG_CXX_LIBRARY' => 'libc++'
    }
  end
  