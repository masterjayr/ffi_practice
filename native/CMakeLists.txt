cmake_minimum_required(VERSION 3.10)

project(ffi_practice_native)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(
    ffi_practice_native 
    SHARED
    src/native.cpp
)

target_include_directories(
    ffi_practice_native
    PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_library(opencv_java4 SHARED IMPORTED)

set_target_properties(opencv_java4 PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/android/${ANDROID_ABI}/libopencv_java4.so 
)

add_library(zxing STATIC IMPORTED)

set_target_properties(zxing PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_CURRENT_SOURCE_DIR}/libs/android/${ANDROID_ABI}/libZXing.a
)

target_link_libraries(
    ffi_practice_native
    opencv_java4
    zxing
)