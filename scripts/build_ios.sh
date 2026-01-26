#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/ios"
THIRD_PARTY_DIR="$ROOT_DIR/.build/third_party"
IOS_FRAMEWORKS_DIR="$ROOT_DIR/ios/Frameworks"
NATIVE_IOS_FRAMEWORKS_DIR="$ROOT_DIR/native/ios/Frameworks"

mkdir -p "$BUILD_DIR" "$THIRD_PARTY_DIR" "$IOS_FRAMEWORKS_DIR" "$NATIVE_IOS_FRAMEWORKS_DIR"

# -------------------------
# CONFIG YOU’LL TWEAK LATER
# -------------------------

# Where to get ZXing source from:
ZXING_GIT_URL="https://github.com/zxing-cpp/zxing-cpp.git"
ZXING_GIT_REF="master" # or a tag like "v2.3.0"

# OpenCV source of truth (choose one):
# 1) If you already have opencv2.framework or opencv2.xcframework in native/ios/Frameworks,
#    the script will use it.
# 2) Otherwise it will try to download a zip from a URL you set below.
OPENCV_ZIP_URL=""   # (later) point to your GitHub Release asset
OPENCV_ZIP_SHA256="" # optional integrity check

# -------------------------
# Helpers
# -------------------------

log() { echo "[$(date +"%H:%M:%S")] $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1"; exit 1; }
}

ensure_tools() {
  need_cmd git
  need_cmd cmake
  need_cmd xcodebuild
  need_cmd lipo
  need_cmd nm
  need_cmd rsync
  need_cmd unzip
}

clone_or_update_repo() {
  local url="$1"
  local ref="$2"
  local dest="$3"

  if [[ ! -d "$dest/.git" ]]; then
    log "Cloning $url -> $dest"
    git clone --depth 1 --branch "$ref" "$url" "$dest"
  else
    log "Updating $dest"
    git -C "$dest" fetch --all --tags
    git -C "$dest" checkout "$ref"
    git -C "$dest" pull --ff-only || true
  fi
}

# Creates a modulemap-enabled header bundle so we can do:
#   #include <ZXing/ImageView.h>
prepare_zxing_headers_bundle() {
  local zxing_src="$1"
  local out_headers_root="$2"  # e.g. $BUILD_DIR/zxing_headers
  local zxing_headers_dir="$out_headers_root/ZXing"

  rm -rf "$out_headers_root"
  mkdir -p "$zxing_headers_dir"

  # Copy ALL headers from core/src into ZXing/
  cp "$zxing_src/core/src/"*.h "$zxing_headers_dir/"

  # Umbrella header (minimal; modulemap exports everything anyway)
  cat > "$zxing_headers_dir/ZXing.h" <<'EOF'
#pragma once
// Umbrella header for ZXing module
EOF

  # Module map
  cat > "$zxing_headers_dir/module.modulemap" <<'EOF'
framework module ZXing {
  umbrella header "ZXing.h"
  export *
  module * { export * }
}
EOF
}

# Build ZXing static library for one platform/arch into a build folder.
build_zxing_one() {
  local zxing_src="$1"
  local build_out="$2"
  local sdk="$3"           # iphoneos | iphonesimulator
  local arch="$4"          # arm64 | x86_64

  rm -rf "$build_out"
  mkdir -p "$build_out"
  pushd "$build_out" >/dev/null

  log "Configuring ZXing for sdk=$sdk arch=$arch"

  cmake "$zxing_src" \
  -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DZXING_BUILD_SHARED=OFF \
  -DZXING_BUILD_EXAMPLES=OFF \
  -DZXING_BUILD_TESTS=OFF \
  -DZXING_BUILD_UNIT_TESTS=OFF \
  -DZXING_ENABLE_ZINT=OFF \
  -DZXING_ENABLE_QRCODE=ON \
  -DZXING_ENABLE_ONED=OFF \
  -DZXING_ENABLE_PDF417=OFF \
  -DZXING_ENABLE_AZTEC=OFF \
  -DZXING_ENABLE_DATAMATRIX=OFF \
  -DZXING_ENABLE_MAXICODE=OFF \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES="$arch" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON

  log "Building ZXing for sdk=$sdk arch=$arch"
  cmake --build . --config Release --target ZXing

  popd >/dev/null

  # ZXing outputs often end up in core/ as libZXing.a
  if [[ ! -f "$build_out/core/libZXing.a" ]]; then
    echo "Expected $build_out/core/libZXing.a not found"
    find "$build_out" -maxdepth 3 -type f -name "libZXing.a" -print
    exit 1
  fi
}

create_zxing_xcframework() {
  local device_lib="$1"     # path to libZXing.a (iphoneos arm64)
  local sim_arm64_lib="$2"  # path to libZXing.a (iphonesimulator arm64)
  local sim_x64_lib="$3"    # path to libZXing.a (iphonesimulator x86_64)
  local headers_root="$4"   # path to headers root (contains ZXing/...)
  local out_xc="$5"         # output ZXing.xcframework path

  rm -rf "$out_xc"
  log "Creating ZXing.xcframework"

  lipo -create \
  "$sim_arm64_lib" \
  "$sim_x64_lib" \
  -output "$BUILD_DIR/libZXing_simulator.a"

  xcodebuild -create-xcframework \
  -library "$device_lib" -headers "$headers_root" \
  -library "$BUILD_DIR/libZXing_simulator.a" -headers "$headers_root" \
  -output "$out_xc"
}

ensure_opencv_present() {
  # Accept either framework or xcframework.
  # Priority: native/ios/Frameworks first
  if [[ -d "$NATIVE_IOS_FRAMEWORKS_DIR/opencv2.framework" ]] || [[ -d "$NATIVE_IOS_FRAMEWORKS_DIR/opencv2.xcframework" ]]; then
    log "OpenCV found in native/ios/Frameworks"
    return 0
  fi

  if [[ -z "$OPENCV_ZIP_URL" ]]; then
    echo "OpenCV not found in native/ios/Frameworks and OPENCV_ZIP_URL is empty."
    echo "Put opencv2.framework or opencv2.xcframework into native/ios/Frameworks OR provide OPENCV_ZIP_URL."
    exit 1
  fi

  # Download if not present
  local zip_path="$THIRD_PARTY_DIR/opencv_ios.zip"
  log "Downloading OpenCV from $OPENCV_ZIP_URL"
  curl -L "$OPENCV_ZIP_URL" -o "$zip_path"

  if [[ -n "$OPENCV_ZIP_SHA256" ]]; then
    echo "$OPENCV_ZIP_SHA256  $zip_path" | shasum -a 256 -c -
  fi

  log "Unzipping OpenCV into native/ios/Frameworks"
  unzip -o "$zip_path" -d "$NATIVE_IOS_FRAMEWORKS_DIR"
}

# Build YOUR framework as an xcframework.
# This assumes you have an Xcode project under native/ios/ffi_practice_native that produces ffi_practice_native.framework.
build_ffi_practice_native_xcframework() {
  local zxing_xc="$1"
  local out_xc="$2"

  local project_path="$ROOT_DIR/native/ios/ffi_practice_native/ffi_practice_native.xcodeproj"
  local scheme="ffi_practice_native"
  local derived="$BUILD_DIR/derived"

  rm -rf "$derived"
  mkdir -p "$derived"

  # Ensure deps exist
  ensure_opencv_present

  # Copy ZXing.xcframework into native/ios/Frameworks for Xcode to find
  rsync -a --delete "$zxing_xc" "$NATIVE_IOS_FRAMEWORKS_DIR/ZXing.xcframework"

  # Build archive for device
  log "Archiving ffi_practice_native (iphoneos)"
  xcodebuild archive \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$derived/ffi_practice_native-iphoneos.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO \
    DEAD_CODE_STRIPPING=NO

  # Build archive for simulator (arm64+x86_64)
  # log "Archiving ffi_practice_native (iphonesimulator)"
  # xcodebuild archive \
  #   -project "$project_path" \
  #   -scheme "$scheme" \
  #   -configuration Release \
  #   -sdk iphonesimulator \
  #   -archivePath "$derived/ffi_practice_native-iphonesimulator.xcarchive" \
  #   SKIP_INSTALL=NO \
  #   BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  #   CODE_SIGNING_ALLOWED=NO \
  #   DEAD_CODE_STRIPPING=NO \
  #   "ARCHS=arm64 x86_64"

  # Create final xcframework
  # rm -rf "$out_xc"
  # log "Creating ffi_practice_native.xcframework"
  # xcodebuild -create-xcframework \
  #   -framework "$derived/ffi_practice_native-iphoneos.xcarchive/Products/Library/Frameworks/ffi_practice_native.framework" \
  #   -framework "$derived/ffi_practice_native-iphonesimulator.xcarchive/Products/Library/Frameworks/ffi_practice_native.framework" \
  #   -output "$out_xc"
  log "Creating ffi_practice_native.xcframework (device-only)"

  rm -rf "$out_xc"

  xcodebuild -create-xcframework \
    -framework "$derived/ffi_practice_native-iphoneos.xcarchive/Products/Library/Frameworks/ffi_practice_native.framework" \
    -output "$out_xc"

}

# -------------------------
# Main
# -------------------------

main() {
  ensure_tools

  local zxing_src="$THIRD_PARTY_DIR/zxing-cpp"
  clone_or_update_repo "$ZXING_GIT_URL" "$ZXING_GIT_REF" "$zxing_src"
  log "Initializing ZXing submodules"
  git -C "$zxing_src" submodule update --init --recursive


  # Build ZXing libs
  local b_device="$BUILD_DIR/zxing-ios-arm64"
  local b_sim_arm64="$BUILD_DIR/zxing-sim-arm64"
  local b_sim_x64="$BUILD_DIR/zxing-sim-x86_64"

  build_zxing_one "$zxing_src" "$b_device" "iphoneos" "arm64"
  build_zxing_one "$zxing_src" "$b_sim_arm64" "iphonesimulator" "arm64"
  build_zxing_one "$zxing_src" "$b_sim_x64" "iphonesimulator" "x86_64"

  # Prepare headers bundle + create ZXing.xcframework
  local headers_root="$BUILD_DIR/zxing_headers"
  prepare_zxing_headers_bundle "$zxing_src" "$headers_root"

  local zxing_xc="$BUILD_DIR/ZXing.xcframework"
  create_zxing_xcframework \
    "$b_device/core/libZXing.a" \
    "$b_sim_arm64/core/libZXing.a" \
    "$b_sim_x64/core/libZXing.a" \
    "$headers_root" \
    "$zxing_xc"

  # Build your native xcframework that will be shipped
  local out_native_xc="$IOS_FRAMEWORKS_DIR/ffi_practice_native.xcframework"
  build_ffi_practice_native_xcframework "$zxing_xc" "$out_native_xc"

  log "✅ Done. Output:"
  log "   $out_native_xc"
}

main "$@"
