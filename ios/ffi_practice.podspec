Pod::Spec.new do |s|
  s.name             = 'ffi_practice'
  s.version          = '0.0.4'
  s.summary          = 'FFI QR Scanner'
  s.description      = 'FFI-based QR scanner using ZXing and OpenCV'
  s.homepage         = 'https://github.com/masterjayr/ffi_practice'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'You' => 'masterjayr97@email.com' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '12.0'

  # 🔑 Download xcframework from GitHub Releases (runs even for local :path references)
  s.prepare_command = <<-CMD
    set -e
    FRAMEWORK_NAME="ffi_practice_native.xcframework"
    ZIP_URL="https://github.com/masterjayr/ffi_practice/releases/download/v#{s.version}/ffi_practice_native-ios.zip"
    
    if [ -d "$FRAMEWORK_NAME" ]; then
      echo "✅ $FRAMEWORK_NAME already exists, skipping download"
    else
      echo "⬇️  Downloading $ZIP_URL"
      curl -L -o ffi_practice_native-ios.zip "$ZIP_URL"
      echo "📦 Unzipping..."
      unzip -o ffi_practice_native-ios.zip
      rm ffi_practice_native-ios.zip
      
      if [ ! -d "$FRAMEWORK_NAME" ]; then
        echo "❌ Error: $FRAMEWORK_NAME not found after unzip"
        exit 1
      fi
      echo "✅ $FRAMEWORK_NAME ready"
    fi
  CMD

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