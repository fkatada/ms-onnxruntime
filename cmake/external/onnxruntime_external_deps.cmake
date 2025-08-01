# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

message(STATUS "Loading Dependencies URLs ...")

include(external/helper_functions.cmake)

file(STRINGS deps.txt ONNXRUNTIME_DEPS_LIST)
foreach(ONNXRUNTIME_DEP IN LISTS ONNXRUNTIME_DEPS_LIST)
  # Lines start with "#" are comments
  if(NOT ONNXRUNTIME_DEP MATCHES "^#")
    # The first column is name
    list(POP_FRONT ONNXRUNTIME_DEP ONNXRUNTIME_DEP_NAME)
    # The second column is URL
    # The URL below may be a local file path or an HTTPS URL
    list(POP_FRONT ONNXRUNTIME_DEP ONNXRUNTIME_DEP_URL)
    set(DEP_URL_${ONNXRUNTIME_DEP_NAME} ${ONNXRUNTIME_DEP_URL})
    # The third column is SHA1 hash value
    set(DEP_SHA1_${ONNXRUNTIME_DEP_NAME} ${ONNXRUNTIME_DEP})

    if(ONNXRUNTIME_DEP_URL MATCHES "^https://")
      # Search a local mirror folder
      string(REGEX REPLACE "^https://" "${REPO_ROOT}/mirror/" LOCAL_URL "${ONNXRUNTIME_DEP_URL}")

      if(EXISTS "${LOCAL_URL}")
        cmake_path(ABSOLUTE_PATH LOCAL_URL)
        set(DEP_URL_${ONNXRUNTIME_DEP_NAME} "${LOCAL_URL}")
      endif()
    endif()
  endif()
endforeach()

message(STATUS "Loading Dependencies ...")
include(FetchContent)

# ABSL should be included before protobuf because protobuf may use absl
include(external/abseil-cpp.cmake)

set(RE2_BUILD_TESTING OFF CACHE BOOL "" FORCE)

onnxruntime_fetchcontent_declare(
    re2
    URL ${DEP_URL_re2}
    URL_HASH SHA1=${DEP_SHA1_re2}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS NAMES re2
)
onnxruntime_fetchcontent_makeavailable(re2)

if (onnxruntime_BUILD_UNIT_TESTS)
  # WebAssembly threading support in Node.js is still an experimental feature and
  # not working properly with googletest suite.
  if (CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    set(gtest_disable_pthreads ON)
  endif()
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  if (IOS OR ANDROID)
    # on mobile platforms the absl flags class dumps the flag names (assumably for binary size), which breaks passing
    # any args to gtest executables, such as using --gtest_filter to debug a specific test.
    # Processing of compile definitions:
    # https://github.com/abseil/abseil-cpp/blob/8dc90ff07402cd027daec520bb77f46e51855889/absl/flags/config.h#L21
    # If set, this code throws away the flag and does nothing on registration, which results in no flags being known:
    # https://github.com/abseil/abseil-cpp/blob/8dc90ff07402cd027daec520bb77f46e51855889/absl/flags/flag.h#L205-L217
    set(GTEST_HAS_ABSL OFF CACHE BOOL "" FORCE)
  else()
    set(GTEST_HAS_ABSL ON CACHE BOOL "" FORCE)
  endif()
  # gtest and gmock
  onnxruntime_fetchcontent_declare(
    googletest
    URL ${DEP_URL_googletest}
    URL_HASH SHA1=${DEP_SHA1_googletest}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS 1.14.0...<2.0.0 NAMES GTest
  )
  FetchContent_MakeAvailable(googletest)
endif()

if (onnxruntime_BUILD_BENCHMARKS)
  # We will not need to test benchmark lib itself.
  set(BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "Disable benchmark testing as we don't need it.")
  # We will not need to install benchmark since we link it statically.
  set(BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "Disable benchmark install to avoid overwriting vendor install.")

  onnxruntime_fetchcontent_declare(
    google_benchmark
    URL ${DEP_URL_google_benchmark}
    URL_HASH SHA1=${DEP_SHA1_google_benchmark}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS NAMES benchmark
  )
  onnxruntime_fetchcontent_makeavailable(google_benchmark)
endif()


if(onnxruntime_USE_MIMALLOC)
  add_definitions(-DUSE_MIMALLOC)

  set(MI_OVERRIDE OFF CACHE BOOL "" FORCE)
  set(MI_BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(MI_DEBUG_FULL OFF CACHE BOOL "" FORCE)
  set(MI_BUILD_SHARED OFF CACHE BOOL "" FORCE)
  onnxruntime_fetchcontent_declare(
    mimalloc
    URL ${DEP_URL_mimalloc}
    URL_HASH SHA1=${DEP_SHA1_mimalloc}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS NAMES mimalloc
  )
  FetchContent_MakeAvailable(mimalloc)
endif()

# Download a protoc binary from Internet if needed
if(NOT ONNX_CUSTOM_PROTOC_EXECUTABLE AND NOT onnxruntime_USE_VCPKG)
  # This part of code is only for users' convenience. The code couldn't handle all cases. Users always can manually
  # download protoc from Protobuf's Github release page and pass the local path to the ONNX_CUSTOM_PROTOC_EXECUTABLE
  # variable.
  if (CMAKE_HOST_APPLE)
    # Using CMAKE_CROSSCOMPILING is not recommended for Apple target devices.
    # https://cmake.org/cmake/help/v3.26/variable/CMAKE_CROSSCOMPILING.html
    # To keep it simple, just download and use the universal protoc binary for all Apple host builds.
    onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_mac_universal} URL_HASH SHA1=${DEP_SHA1_protoc_mac_universal} EXCLUDE_FROM_ALL)
    FetchContent_Populate(protoc_binary)
    if(protoc_binary_SOURCE_DIR)
      message(STATUS "Use prebuilt protoc")
      set(ONNX_CUSTOM_PROTOC_EXECUTABLE ${protoc_binary_SOURCE_DIR}/bin/protoc)
      set(PROTOC_EXECUTABLE ${ONNX_CUSTOM_PROTOC_EXECUTABLE})
    endif()
  elseif (CMAKE_CROSSCOMPILING)
    message(STATUS "CMAKE_HOST_SYSTEM_NAME: ${CMAKE_HOST_SYSTEM_NAME}")
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
      if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "AMD64")
        onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_win64} URL_HASH SHA1=${DEP_SHA1_protoc_win64} EXCLUDE_FROM_ALL)
        FetchContent_Populate(protoc_binary)
      elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86")
        onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_win32} URL_HASH SHA1=${DEP_SHA1_protoc_win32} EXCLUDE_FROM_ALL)
        FetchContent_Populate(protoc_binary)
      elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "ARM64")
        onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_win64} URL_HASH SHA1=${DEP_SHA1_protoc_win64} EXCLUDE_FROM_ALL)
        FetchContent_Populate(protoc_binary)
      endif()

      if(protoc_binary_SOURCE_DIR)
        message(STATUS "Use prebuilt protoc")
        set(ONNX_CUSTOM_PROTOC_EXECUTABLE ${protoc_binary_SOURCE_DIR}/bin/protoc.exe)
        set(PROTOC_EXECUTABLE ${ONNX_CUSTOM_PROTOC_EXECUTABLE})
      endif()
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
      if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
        onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_linux_x64} URL_HASH SHA1=${DEP_SHA1_protoc_linux_x64} EXCLUDE_FROM_ALL)
        FetchContent_Populate(protoc_binary)
      elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.86|x86?)$")
        onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_linux_x86} URL_HASH SHA1=${DEP_SHA1_protoc_linux_x86} EXCLUDE_FROM_ALL)
        FetchContent_Populate(protoc_binary)
      elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^aarch64.*")
        onnxruntime_fetchcontent_declare(protoc_binary URL ${DEP_URL_protoc_linux_aarch64} URL_HASH SHA1=${DEP_SHA1_protoc_linux_aarch64} EXCLUDE_FROM_ALL)
        FetchContent_Populate(protoc_binary)
      endif()

      if(protoc_binary_SOURCE_DIR)
        message(STATUS "Use prebuilt protoc")
        set(ONNX_CUSTOM_PROTOC_EXECUTABLE ${protoc_binary_SOURCE_DIR}/bin/protoc)
        set(PROTOC_EXECUTABLE ${ONNX_CUSTOM_PROTOC_EXECUTABLE})
      endif()
    endif()

    if(NOT ONNX_CUSTOM_PROTOC_EXECUTABLE)
      message(FATAL_ERROR "ONNX_CUSTOM_PROTOC_EXECUTABLE must be set to cross-compile.")
    endif()
  endif()
endif()

# if ONNX_CUSTOM_PROTOC_EXECUTABLE is set we don't need to build the protoc binary
if (ONNX_CUSTOM_PROTOC_EXECUTABLE)
  if (NOT EXISTS "${ONNX_CUSTOM_PROTOC_EXECUTABLE}")
    message(FATAL_ERROR "ONNX_CUSTOM_PROTOC_EXECUTABLE is set to '${ONNX_CUSTOM_PROTOC_EXECUTABLE}' "
                        "but protoc executable was not found there.")
  endif()

  set(protobuf_BUILD_PROTOC_BINARIES OFF CACHE BOOL "Build protoc" FORCE)
endif()

#Here we support two build mode:
#1. if ONNX_CUSTOM_PROTOC_EXECUTABLE is set, build Protobuf from source, except protoc.exe. This mode is mainly
#   for cross-compiling
#2. if ONNX_CUSTOM_PROTOC_EXECUTABLE is not set, Compile everything(including protoc) from source code.
if(Patch_FOUND)
  set(ONNXRUNTIME_PROTOBUF_PATCH_COMMAND ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/protobuf/protobuf_cmake.patch &&
                                         ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/protobuf/protobuf_android_log.patch)
else()
 set(ONNXRUNTIME_PROTOBUF_PATCH_COMMAND "")
endif()

#Protobuf depends on absl and utf8_range
onnxruntime_fetchcontent_declare(
  Protobuf
  URL ${DEP_URL_protobuf}
  URL_HASH SHA1=${DEP_SHA1_protobuf}
  PATCH_COMMAND ${ONNXRUNTIME_PROTOBUF_PATCH_COMMAND}
  EXCLUDE_FROM_ALL
  FIND_PACKAGE_ARGS NAMES Protobuf protobuf
)

set(protobuf_BUILD_TESTS OFF CACHE BOOL "Build protobuf tests" FORCE)
#TODO: we'd better to turn the following option off. However, it will cause
# ".\build.bat --config Debug --parallel --skip_submodule_sync --update" fail with an error message:
# install(EXPORT "ONNXTargets" ...) includes target "onnx_proto" which requires target "libprotobuf-lite" that is
# not in any export set.
#set(protobuf_INSTALL OFF CACHE BOOL "Install protobuf binaries and files" FORCE)
set(protobuf_USE_EXTERNAL_GTEST ON CACHE BOOL "" FORCE)

if (ANDROID)
  set(protobuf_WITH_ZLIB OFF CACHE BOOL "Build protobuf with zlib support" FORCE)
endif()

if (onnxruntime_DISABLE_RTTI)
  set(protobuf_DISABLE_RTTI ON CACHE BOOL "Remove runtime type information in the binaries" FORCE)
endif()

include(protobuf_function)
#protobuf end

onnxruntime_fetchcontent_makeavailable(Protobuf)
if(Protobuf_FOUND)
  message(STATUS "Using protobuf from find_package(or vcpkg). Protobuf version: ${Protobuf_VERSION}")
else()
  if(protobuf_SOURCE_DIR)
    if(onnxruntime_USE_WEBGPU)
      set(DAWN_PROTOBUF_DIR ${protobuf_SOURCE_DIR})
    endif()
  endif()
  # Adjust warning flags
  if (TARGET libprotoc)
    if (NOT MSVC)
      target_compile_options(libprotoc PRIVATE "-w")
    endif()
  endif()
  if (TARGET protoc)
    add_executable(protobuf::protoc ALIAS protoc)
    if (UNIX AND onnxruntime_ENABLE_LTO)
      #https://github.com/protocolbuffers/protobuf/issues/5923
      target_link_options(protoc PRIVATE "-Wl,--no-as-needed")
    endif()
    if (NOT MSVC)
      target_compile_options(protoc PRIVATE "-w")
    endif()
    get_target_property(PROTOC_OSX_ARCH protoc OSX_ARCHITECTURES)
    if (PROTOC_OSX_ARCH)
      if (${CMAKE_HOST_SYSTEM_PROCESSOR} IN_LIST PROTOC_OSX_ARCH)
        message(STATUS "protoc can run")
      else()
        list(APPEND PROTOC_OSX_ARCH ${CMAKE_HOST_SYSTEM_PROCESSOR})
        set_target_properties(protoc PROPERTIES OSX_ARCHITECTURES "${CMAKE_HOST_SYSTEM_PROCESSOR}")
        set_target_properties(libprotoc PROPERTIES OSX_ARCHITECTURES "${PROTOC_OSX_ARCH}")
        set_target_properties(libprotobuf PROPERTIES OSX_ARCHITECTURES "${PROTOC_OSX_ARCH}")
      endif()
    endif()
   endif()
  if (TARGET libprotobuf AND NOT MSVC)
    target_compile_options(libprotobuf PRIVATE "-w")
  endif()
  if (TARGET libprotobuf-lite AND NOT MSVC)
    target_compile_options(libprotobuf-lite PRIVATE "-w")
  endif()
endif()
if (onnxruntime_USE_FULL_PROTOBUF)
  set(PROTOBUF_LIB protobuf::libprotobuf)
else()
  set(PROTOBUF_LIB protobuf::libprotobuf-lite)
endif()

# date
set(ENABLE_DATE_TESTING  OFF CACHE BOOL "" FORCE)
set(USE_SYSTEM_TZ_DB  ON CACHE BOOL "" FORCE)

onnxruntime_fetchcontent_declare(
  date
  URL ${DEP_URL_date}
  URL_HASH SHA1=${DEP_SHA1_date}
  EXCLUDE_FROM_ALL
  FIND_PACKAGE_ARGS 3...<4 NAMES date
)
onnxruntime_fetchcontent_makeavailable(date)

if(NOT TARGET Boost::mp11)
  if(onnxruntime_USE_VCPKG)
     find_package(Boost REQUIRED)
     message(STATUS "Aliasing Boost::headers to Boost::mp11")
     add_library(Boost::mp11 ALIAS Boost::headers)
  else()
    onnxruntime_fetchcontent_declare(
     mp11
     URL ${DEP_URL_mp11}
     EXCLUDE_FROM_ALL
     FIND_PACKAGE_ARGS NAMES Boost
    )
    FetchContent_Populate(mp11)
    if(NOT TARGET Boost::mp11)
      add_library(Boost::mp11 IMPORTED INTERFACE)
      target_include_directories(Boost::mp11 INTERFACE $<BUILD_INTERFACE:${mp11_SOURCE_DIR}/include>)
    endif()
  endif()
endif()

set(JSON_BuildTests OFF CACHE INTERNAL "")
set(JSON_Install ON CACHE INTERNAL "")

onnxruntime_fetchcontent_declare(
    nlohmann_json
    URL ${DEP_URL_json}
    URL_HASH SHA1=${DEP_SHA1_json}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS 3.10 NAMES nlohmann_json
)
onnxruntime_fetchcontent_makeavailable(nlohmann_json)

#TODO: include clog first
if (onnxruntime_ENABLE_CPUINFO)
  # Adding pytorch CPU info library
  # TODO!! need a better way to find out the supported architectures
  list(LENGTH CMAKE_OSX_ARCHITECTURES CMAKE_OSX_ARCHITECTURES_LEN)
  if (APPLE)
    if (CMAKE_OSX_ARCHITECTURES_LEN LESS_EQUAL 1)
      set(CPUINFO_SUPPORTED TRUE)
    elseif (onnxruntime_BUILD_APPLE_FRAMEWORK)
      # We stitch multiple static libraries together when onnxruntime_BUILD_APPLE_FRAMEWORK is true,
      # but that would not work for universal static libraries
      message(FATAL_ERROR "universal binary is not supported for apple framework")
    endif()
  else()
    # if xnnpack is enabled in a wasm build it needs clog from cpuinfo, but we won't internally use cpuinfo
    # so we don't set CPUINFO_SUPPORTED in the CXX flags below.
    if (CMAKE_SYSTEM_NAME STREQUAL "Emscripten" AND NOT onnxruntime_USE_XNNPACK)
      set(CPUINFO_SUPPORTED FALSE)
    else()
      set(CPUINFO_SUPPORTED TRUE)
    endif()
    if (WIN32)
      set(CPUINFO_SUPPORTED TRUE)
    elseif (NOT ${onnxruntime_target_platform} MATCHES "^(i[3-6]86|AMD64|x86(_64)?|armv[5-8].*|aarch64|arm64)$")
      message(WARNING
        "Target processor architecture \"${onnxruntime_target_platform}\" is not supported in cpuinfo. "
        "cpuinfo not included."
      )
      set(CPUINFO_SUPPORTED FALSE)
    endif()
  endif()
else()
  set(CPUINFO_SUPPORTED FALSE)
endif()

if (CPUINFO_SUPPORTED)
  if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(IOS ON CACHE INTERNAL "")
    set(IOS_ARCH "${CMAKE_OSX_ARCHITECTURES}" CACHE INTERNAL "")
  endif()

  # if this is a wasm build with xnnpack (only type of wasm build where cpuinfo is involved)
  # we do not use cpuinfo in ORT code, so don't define CPUINFO_SUPPORTED.
  if (NOT CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    string(APPEND CMAKE_CXX_FLAGS " -DCPUINFO_SUPPORTED")
  endif()


  set(CPUINFO_BUILD_TOOLS OFF CACHE INTERNAL "")
  set(CPUINFO_BUILD_UNIT_TESTS OFF CACHE INTERNAL "")
  set(CPUINFO_BUILD_MOCK_TESTS OFF CACHE INTERNAL "")
  set(CPUINFO_BUILD_BENCHMARKS OFF CACHE INTERNAL "")
  if (onnxruntime_target_platform STREQUAL "ARM64EC" OR onnxruntime_target_platform STREQUAL "ARM64")
      message(STATUS "Applying a patch for Windows ARM64/ARM64EC in cpuinfo")
      onnxruntime_fetchcontent_declare(
        pytorch_cpuinfo
        URL ${DEP_URL_pytorch_cpuinfo}
        URL_HASH SHA1=${DEP_SHA1_pytorch_cpuinfo}
        EXCLUDE_FROM_ALL
        PATCH_COMMAND ${Patch_EXECUTABLE} -p1 < ${PROJECT_SOURCE_DIR}/patches/cpuinfo/9bb12d342fd9479679d505d93a478a6f9cd50a47.patch
        FIND_PACKAGE_ARGS NAMES cpuinfo
      )
  else()
      onnxruntime_fetchcontent_declare(
        pytorch_cpuinfo
        URL ${DEP_URL_pytorch_cpuinfo}
        URL_HASH SHA1=${DEP_SHA1_pytorch_cpuinfo}
        EXCLUDE_FROM_ALL
        FIND_PACKAGE_ARGS NAMES cpuinfo
      )
  endif()
  set(ONNXRUNTIME_CPUINFO_PROJ pytorch_cpuinfo)
  onnxruntime_fetchcontent_makeavailable(${ONNXRUNTIME_CPUINFO_PROJ})
  if(TARGET cpuinfo::cpuinfo AND NOT TARGET cpuinfo)
    message(STATUS "Aliasing cpuinfo::cpuinfo to cpuinfo")
    add_library(cpuinfo ALIAS cpuinfo::cpuinfo)
  endif()
endif()

if(onnxruntime_USE_CUDA)
  onnxruntime_fetchcontent_declare(
    GSL
    URL ${DEP_URL_microsoft_gsl}
    URL_HASH SHA1=${DEP_SHA1_microsoft_gsl}
    PATCH_COMMAND ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/gsl/1064.patch
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS 4.0 NAMES Microsoft.GSL
  )
else()
  onnxruntime_fetchcontent_declare(
    GSL
    URL ${DEP_URL_microsoft_gsl}
    URL_HASH SHA1=${DEP_SHA1_microsoft_gsl}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS 4.0 NAMES Microsoft.GSL
  )
endif()
set(GSL_TARGET "Microsoft.GSL::GSL")
set(GSL_INCLUDE_DIR "$<TARGET_PROPERTY:${GSL_TARGET},INTERFACE_INCLUDE_DIRECTORIES>")
onnxruntime_fetchcontent_makeavailable(GSL)

if (NOT GSL_FOUND AND NOT onnxruntime_BUILD_SHARED_LIB)
  install(TARGETS GSL EXPORT ${PROJECT_NAME}Targets
  ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

find_path(safeint_SOURCE_DIR NAMES "SafeInt.hpp")
if(NOT safeint_SOURCE_DIR)
  unset(safeint_SOURCE_DIR)
  onnxruntime_fetchcontent_declare(
      safeint
      URL ${DEP_URL_safeint}
      URL_HASH SHA1=${DEP_SHA1_safeint}
      EXCLUDE_FROM_ALL
  )

  # use fetch content rather than makeavailable because safeint only includes unconditional test targets
  FetchContent_Populate(safeint)
endif()
add_library(safeint_interface IMPORTED INTERFACE)
target_include_directories(safeint_interface INTERFACE ${safeint_SOURCE_DIR})


# Flatbuffers
if(onnxruntime_USE_VCPKG)
  find_package(flatbuffers REQUIRED)
else()
# We do not need to build flatc for iOS or Android Cross Compile
if (CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_SYSTEM_NAME STREQUAL "Android" OR CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
  set(FLATBUFFERS_BUILD_FLATC OFF CACHE BOOL "FLATBUFFERS_BUILD_FLATC" FORCE)
endif()
set(FLATBUFFERS_BUILD_TESTS OFF CACHE BOOL "FLATBUFFERS_BUILD_TESTS" FORCE)
set(FLATBUFFERS_INSTALL ON CACHE BOOL "FLATBUFFERS_INSTALL" FORCE)
set(FLATBUFFERS_BUILD_FLATHASH OFF CACHE BOOL "FLATBUFFERS_BUILD_FLATHASH" FORCE)
set(FLATBUFFERS_BUILD_FLATLIB ON CACHE BOOL "FLATBUFFERS_BUILD_FLATLIB" FORCE)
if(Patch_FOUND)
  set(ONNXRUNTIME_FLATBUFFERS_PATCH_COMMAND ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/flatbuffers/flatbuffers.patch)
else()
 set(ONNXRUNTIME_FLATBUFFERS_PATCH_COMMAND "")
endif()

#flatbuffers 1.11.0 does not have flatbuffers::IsOutRange, therefore we require 1.12.0+
onnxruntime_fetchcontent_declare(
    flatbuffers
    URL ${DEP_URL_flatbuffers}
    URL_HASH SHA1=${DEP_SHA1_flatbuffers}
    PATCH_COMMAND ${ONNXRUNTIME_FLATBUFFERS_PATCH_COMMAND}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS 23.5.9 NAMES Flatbuffers flatbuffers
)

onnxruntime_fetchcontent_makeavailable(flatbuffers)
if(NOT flatbuffers_FOUND)
  if(NOT TARGET flatbuffers::flatbuffers)
    add_library(flatbuffers::flatbuffers ALIAS flatbuffers)
  endif()
  if(TARGET flatc AND NOT TARGET flatbuffers::flatc)
    add_executable(flatbuffers::flatc ALIAS flatc)
  endif()
  if (GDK_PLATFORM)
    # cstdlib only defines std::getenv when _CRT_USE_WINAPI_FAMILY_DESKTOP_APP is defined, which
    # is probably an oversight for GDK/Xbox builds (::getenv exists and works).
    file(WRITE ${CMAKE_BINARY_DIR}/gdk_cstdlib_wrapper.h [[
#pragma once
#ifdef __cplusplus
#include <cstdlib>
namespace std { using ::getenv; }
#endif
]])
    if(TARGET flatbuffers)
      target_compile_options(flatbuffers PRIVATE /FI${CMAKE_BINARY_DIR}/gdk_cstdlib_wrapper.h)
    endif()
    if(TARGET flatc)
      target_compile_options(flatc PRIVATE /FI${CMAKE_BINARY_DIR}/gdk_cstdlib_wrapper.h)
    endif()
  endif()
endif()
endif()

# ONNX
if (NOT onnxruntime_USE_FULL_PROTOBUF)
  set(ONNX_USE_LITE_PROTO ON CACHE BOOL "" FORCE)
else()
  set(ONNX_USE_LITE_PROTO OFF CACHE BOOL "" FORCE)
endif()

if(Patch_FOUND)
  set(ONNXRUNTIME_ONNX_PATCH_COMMAND ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/onnx/onnx.patch)
else()
  set(ONNXRUNTIME_ONNX_PATCH_COMMAND "")
endif()

if(onnxruntime_ENABLE_PYTHON)
  if(onnxruntime_USE_VCPKG)
    find_package(pybind11 CONFIG REQUIRED)
  else()
    include(pybind11)
  endif()
if(TARGET pybind11::module)
  message("Setting pybind11_lib")
  set(pybind11_lib pybind11::module)
else()
  message("Setting pybind11_dep")
  set(pybind11_dep pybind11::pybind11)
endif()

endif()
onnxruntime_fetchcontent_declare(
  onnx
  URL ${DEP_URL_onnx}
  URL_HASH SHA1=${DEP_SHA1_onnx}
  PATCH_COMMAND ${ONNXRUNTIME_ONNX_PATCH_COMMAND}
  EXCLUDE_FROM_ALL
  FIND_PACKAGE_ARGS NAMES ONNX onnx
)

onnxruntime_fetchcontent_makeavailable(onnx)

if(TARGET ONNX::onnx AND NOT TARGET onnx)
  message(STATUS "Aliasing ONNX::onnx to onnx")
  add_library(onnx ALIAS ONNX::onnx)
endif()
if(TARGET ONNX::onnx_proto AND NOT TARGET onnx_proto)
  message(STATUS "Aliasing ONNX::onnx_proto to onnx_proto")
  add_library(onnx_proto ALIAS ONNX::onnx_proto)
endif()
if(onnxruntime_USE_VCPKG)
  find_package(Eigen3 CONFIG REQUIRED)
else()
  include(external/eigen.cmake)
endif()

if(WIN32)
  if(onnxruntime_USE_VCPKG)
    find_package(wil CONFIG REQUIRED)
    set(WIL_TARGET "WIL::WIL")
  else()
    include(wil) # FetchContent
  endif()
endif()

# XNNPACK EP
if (onnxruntime_USE_XNNPACK)
  if (onnxruntime_DISABLE_CONTRIB_OPS)
    message(FATAL_ERROR "XNNPACK EP requires the internal NHWC contrib ops to be available "
                         "but onnxruntime_DISABLE_CONTRIB_OPS is ON")
  endif()
  if(onnxruntime_USE_VCPKG)
     FIND_PATH(XNNPACK_HDR xnnpack.h PATH_SUFFIXES include)
     IF(NOT XNNPACK_HDR)
       MESSAGE(FATAL_ERROR "Cannot find xnnpack")
     ENDIF()
     ADD_LIBRARY(xnnpack STATIC IMPORTED)
     find_library(xnnpack_LIBRARY NAMES XNNPACK)
     find_library(microkernels_prod_LIBRARY NAMES xnnpack-microkernels-prod)
     find_package(unofficial-pthreadpool CONFIG REQUIRED)

     target_include_directories(xnnpack INTERFACE "${XNNPACK_HDR}")
     set(XNNPACK_INCLUDE_DIR ${XNNPACK_DIR}/include)
     set(onnxruntime_EXTERNAL_LIBRARIES_XNNPACK ${xnnpack_LIBRARY} ${microkernels_prod_LIBRARY} unofficial::pthreadpool unofficial::pthreadpool_interface)
  else()
    include(xnnpack)
  endif()
endif()

set(onnxruntime_EXTERNAL_LIBRARIES ${onnxruntime_EXTERNAL_LIBRARIES_XNNPACK} ${WIL_TARGET} nlohmann_json::nlohmann_json
                                   onnx onnx_proto ${PROTOBUF_LIB} re2::re2 Boost::mp11 safeint_interface
                                   flatbuffers::flatbuffers ${GSL_TARGET} ${ABSEIL_LIBS} date::date
                                   ${ONNXRUNTIME_CLOG_TARGET_NAME} Eigen3::Eigen)

# The source code of onnx_proto is generated, we must build this lib first before starting to compile the other source code that uses ONNX protobuf types.
# The other libs do not have the problem. All the sources are already there. We can compile them in any order.
set(onnxruntime_EXTERNAL_DEPENDENCIES onnx_proto flatbuffers::flatbuffers)

if(NOT (onnx_FOUND OR ONNX_FOUND)) # building ONNX from source
  target_compile_definitions(onnx PUBLIC $<TARGET_PROPERTY:onnx_proto,INTERFACE_COMPILE_DEFINITIONS> PRIVATE "__ONNX_DISABLE_STATIC_REGISTRATION")
  if (NOT onnxruntime_USE_FULL_PROTOBUF)
    target_compile_definitions(onnx PUBLIC "__ONNX_NO_DOC_STRINGS")
  endif()
endif()

if (onnxruntime_RUN_ONNX_TESTS)
  add_definitions(-DORT_RUN_EXTERNAL_ONNX_TESTS)
endif()

if(onnxruntime_ENABLE_DLPACK)
  message(STATUS "dlpack is enabled.")

  onnxruntime_fetchcontent_declare(
    dlpack
    URL ${DEP_URL_dlpack}
    URL_HASH SHA1=${DEP_SHA1_dlpack}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS NAMES dlpack
  )
  onnxruntime_fetchcontent_makeavailable(dlpack)
endif()

if(onnxruntime_ENABLE_TRAINING OR (onnxruntime_ENABLE_TRAINING_APIS AND onnxruntime_BUILD_UNIT_TESTS))
  # Once code under orttraining/orttraining/models dir is removed "onnxruntime_ENABLE_TRAINING" should be removed from
  # this conditional
  onnxruntime_fetchcontent_declare(
    cxxopts
    URL ${DEP_URL_cxxopts}
    URL_HASH SHA1=${DEP_SHA1_cxxopts}
    EXCLUDE_FROM_ALL
    FIND_PACKAGE_ARGS NAMES cxxopts
  )
  set(CXXOPTS_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  set(CXXOPTS_BUILD_TESTS OFF CACHE BOOL "" FORCE)
  onnxruntime_fetchcontent_makeavailable(cxxopts)
endif()


if (onnxruntime_USE_WEBGPU)
  # TODO: the following code is used to disable building Dawn using vcpkg temporarily
  # until we figure out how to resolve the packaging pipeline failures
  #
  # if (onnxruntime_USE_VCPKG AND NOT CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
  if (FALSE)
    # vcpkg does not support Emscripten yet
    find_package(dawn REQUIRED)
  else()
    #
    # Please keep the following in sync with cmake/vcpkg-ports/dawn/portfile.cmake
    #
    set(DAWN_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
    set(DAWN_ENABLE_NULL OFF CACHE BOOL "" FORCE)
    set(DAWN_FETCH_DEPENDENCIES ON CACHE BOOL "" FORCE)
    set(DAWN_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    if (NOT CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
      if (onnxruntime_BUILD_DAWN_MONOLITHIC_LIBRARY)
        set(DAWN_BUILD_MONOLITHIC_LIBRARY ON CACHE BOOL "" FORCE)
        set(DAWN_ENABLE_INSTALL ON CACHE BOOL "" FORCE)

        if (onnxruntime_USE_EXTERNAL_DAWN)
          message(FATAL_ERROR "onnxruntime_USE_EXTERNAL_DAWN and onnxruntime_BUILD_DAWN_MONOLITHIC_LIBRARY cannot be enabled at the same time.")
        endif()
      else()
        # use dawn::dawn_native and dawn::dawn_proc instead of the monolithic dawn::webgpu_dawn to minimize binary size
        set(DAWN_BUILD_MONOLITHIC_LIBRARY OFF CACHE BOOL "" FORCE)
        set(DAWN_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
      endif()

      if (onnxruntime_ENABLE_PIX_FOR_WEBGPU_EP)
        set(DAWN_ENABLE_DESKTOP_GL ON CACHE BOOL "" FORCE)
        set(DAWN_ENABLE_OPENGLES ON CACHE BOOL "" FORCE)
        set(DAWN_SUPPORTS_GLFW_FOR_WINDOWING ON CACHE BOOL "" FORCE)
        set(DAWN_USE_GLFW ON CACHE BOOL "" FORCE)
        set(DAWN_USE_WINDOWS_UI ON CACHE BOOL "" FORCE)
        set(TINT_BUILD_GLSL_WRITER ON CACHE BOOL "" FORCE)
        set(TINT_BUILD_GLSL_VALIDATOR ON CACHE BOOL "" FORCE)
      else()
        set(DAWN_ENABLE_DESKTOP_GL OFF CACHE BOOL "" FORCE)
        set(DAWN_ENABLE_OPENGLES OFF CACHE BOOL "" FORCE)
        set(DAWN_SUPPORTS_GLFW_FOR_WINDOWING OFF CACHE BOOL "" FORCE)
        set(DAWN_USE_GLFW OFF CACHE BOOL "" FORCE)
        set(DAWN_USE_WINDOWS_UI OFF CACHE BOOL "" FORCE)
        set(TINT_BUILD_GLSL_WRITER OFF CACHE BOOL "" FORCE)
        set(TINT_BUILD_GLSL_VALIDATOR OFF CACHE BOOL "" FORCE)
      endif()

      # disable things we don't use
      set(DAWN_DXC_ENABLE_ASSERTS_IN_NDEBUG OFF)
      set(DAWN_USE_X11 OFF CACHE BOOL "" FORCE)

      set(TINT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
      set(TINT_BUILD_CMD_TOOLS OFF CACHE BOOL "" FORCE)
      set(TINT_BUILD_IR_BINARY OFF CACHE BOOL "" FORCE)
      set(TINT_BUILD_SPV_READER OFF CACHE BOOL "" FORCE)  # don't need. disabling is a large binary size saving
      set(TINT_BUILD_WGSL_WRITER ON CACHE BOOL "" FORCE)  # needed to create cache key. runtime error if not enabled.

      # SPIR-V validation shouldn't be required given we're using Tint to create the SPIR-V.
      set(DAWN_ENABLE_SPIRV_VALIDATION OFF CACHE BOOL "" FORCE)

      if (WIN32)
        # building this requires the HLSL writer to be enabled in Tint. TBD if that we need either of these to be ON.
        set(DAWN_USE_BUILT_DXC ON CACHE BOOL "" FORCE)
        set(TINT_BUILD_HLSL_WRITER ON CACHE BOOL "" FORCE)

        if ((NOT onnxruntime_ENABLE_DAWN_BACKEND_VULKAN) AND (NOT onnxruntime_ENABLE_DAWN_BACKEND_D3D12))
          message(FATAL_ERROR "At least one of onnxruntime_ENABLE_DAWN_BACKEND_VULKAN or onnxruntime_ENABLE_DAWN_BACKEND_D3D12 must be enabled when using Dawn on Windows.")
        endif()
        if (onnxruntime_ENABLE_DAWN_BACKEND_VULKAN)
          set(DAWN_ENABLE_VULKAN ON CACHE BOOL "" FORCE)
          set(TINT_BUILD_SPV_WRITER ON CACHE BOOL "" FORCE)
        else()
          set(DAWN_ENABLE_VULKAN OFF CACHE BOOL "" FORCE)
        endif()
        if (onnxruntime_ENABLE_DAWN_BACKEND_D3D12)
          set(DAWN_ENABLE_D3D12 ON CACHE BOOL "" FORCE)
        else()
          set(DAWN_ENABLE_D3D12 OFF CACHE BOOL "" FORCE)
        endif()
        # We are currently always using the D3D12 backend.
        set(DAWN_ENABLE_D3D11 OFF CACHE BOOL "" FORCE)
      endif()
    endif()
    if (onnxruntime_CUSTOM_DAWN_SRC_PATH)
      # use the custom dawn source path if provided
      #
      # specified as:
      # build.py --use_webgpu --cmake_extra_defines "onnxruntime_CUSTOM_DAWN_SRC_PATH=<PATH_TO_DAWN_SRC_ROOT>"
      onnxruntime_fetchcontent_declare(
        dawn
        SOURCE_DIR ${onnxruntime_CUSTOM_DAWN_SRC_PATH}
        EXCLUDE_FROM_ALL
      )
    else()
      set(ONNXRUNTIME_Dawn_PATCH_COMMAND
          # The dawn_destroy_buffer_on_destructor.patch contains the following changes:
          #
          # - (private) Allow WGPUBufferImpl class to destroy the buffer in the destructor
          #   In native implementation, wgpuBufferRelease will trigger the buffer destroy (if refcount decreased to 0). But
          #   in emwgpu implementation, the buffer destroy won't happen. This change adds a destructor to the buffer class
          #   to destroy the buffer when the refcount is 0 for non-external buffers.
          #
          ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/dawn/dawn_destroy_buffer_on_destructor.patch &&

          # The dawn_force_enable_f16_nvidia_vulkan.patch contains the following changes:
          #
          # - (private) Force enable f16 support for NVIDIA Vulkan
          #   Dawn disabled f16 support for NVIDIA Vulkan by default because of crashes in f16 CTS tests (crbug.com/tint/2164).
          #   Since the crashes are limited to specific GPU models, we patched Dawn to remove the restriction.
          #
          ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/dawn/dawn_force_enable_f16_nvidia_vulkan.patch &&

          # The dawn_binskim.patch contains the following changes:
          #
          # - (private) Fulfill the BinSkim requirements
          #   Some build warnings are not allowed to be disabled in project level.
          ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/dawn/dawn_binskim.patch)

      onnxruntime_fetchcontent_declare(
        dawn
        URL ${DEP_URL_dawn}
        URL_HASH SHA1=${DEP_SHA1_dawn}
        PATCH_COMMAND ${ONNXRUNTIME_Dawn_PATCH_COMMAND}
        EXCLUDE_FROM_ALL
      )
    endif()

    onnxruntime_fetchcontent_makeavailable(dawn)
  endif()

  if (NOT CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    if (onnxruntime_BUILD_DAWN_MONOLITHIC_LIBRARY)
      list(APPEND onnxruntime_EXTERNAL_LIBRARIES dawn::webgpu_dawn)
    else()
      if (NOT onnxruntime_USE_EXTERNAL_DAWN)
        list(APPEND onnxruntime_EXTERNAL_LIBRARIES dawn::dawn_native)
      endif()
      list(APPEND onnxruntime_EXTERNAL_LIBRARIES dawn::dawn_proc)
    endif()
  endif()

  if (onnxruntime_ENABLE_PIX_FOR_WEBGPU_EP)
    list(APPEND onnxruntime_EXTERNAL_LIBRARIES webgpu_glfw glfw)
  endif()

  if (NOT CMAKE_SYSTEM_NAME STREQUAL "Emscripten" AND onnxruntime_WGSL_TEMPLATE STREQUAL "dynamic")
    if(onnxruntime_USE_VCPKG)
      find_package(unofficial-duktape CONFIG REQUIRED)
      add_library(duktape_static ALIAS unofficial::duktape::duktape)
    else()
      onnxruntime_fetchcontent_declare(
        duktape
        URL ${DEP_URL_duktape}
        URL_HASH SHA1=${DEP_SHA1_duktape}
        EXCLUDE_FROM_ALL
      )
      onnxruntime_fetchcontent_makeavailable(duktape)

      if(NOT TARGET duktape_static)
        add_library(duktape_static STATIC "${duktape_SOURCE_DIR}/src/duktape.c")
        target_compile_features(duktape_static PRIVATE c_std_99)
        target_include_directories(duktape_static INTERFACE $<BUILD_INTERFACE:${duktape_SOURCE_DIR}/src>)
      endif()
    endif()
  endif()
endif()

if(onnxruntime_USE_COREML)
  # Setup coremltools fp16 and json dependencies for creating an mlpackage.
  #
  # fp16 depends on psimd
  onnxruntime_fetchcontent_declare(psimd URL ${DEP_URL_psimd} URL_HASH SHA1=${DEP_SHA1_psimd} EXCLUDE_FROM_ALL)
  onnxruntime_fetchcontent_makeavailable(psimd)
  set(PSIMD_SOURCE_DIR ${psimd_SOURCE_DIR})
  onnxruntime_fetchcontent_declare(fp16 URL ${DEP_URL_fp16} URL_HASH SHA1=${DEP_SHA1_fp16} EXCLUDE_FROM_ALL)
  set(FP16_BUILD_TESTS OFF CACHE INTERNAL "")
  set(FP16_BUILD_BENCHMARKS OFF CACHE INTERNAL "")
  onnxruntime_fetchcontent_makeavailable(fp16)

  onnxruntime_fetchcontent_declare(
    coremltools
    URL ${DEP_URL_coremltools}
    URL_HASH SHA1=${DEP_SHA1_coremltools}
    PATCH_COMMAND ${Patch_EXECUTABLE} --binary --ignore-whitespace -p1 < ${PROJECT_SOURCE_DIR}/patches/coremltools/crossplatformbuild.patch
    EXCLUDE_FROM_ALL
  )
  # we don't build directly so use Populate. selected files are built from onnxruntime_providers_coreml.cmake
  FetchContent_Populate(coremltools)

endif()

if(onnxruntime_USE_KLEIDIAI)
  # Disable the KleidiAI tests
  set(KLEIDIAI_BUILD_TESTS  OFF)

  onnxruntime_fetchcontent_declare(kleidiai URL ${DEP_URL_kleidiai} URL_HASH SHA1=${DEP_SHA1_kleidiai} EXCLUDE_FROM_ALL)
  onnxruntime_fetchcontent_makeavailable(kleidiai)
endif()

set(onnxruntime_LINK_DIRS)
if (onnxruntime_USE_CUDA)
  find_package(CUDAToolkit REQUIRED)

  if(onnxruntime_CUDNN_HOME)
    file(TO_CMAKE_PATH ${onnxruntime_CUDNN_HOME} onnxruntime_CUDNN_HOME)
    set(CUDNN_PATH ${onnxruntime_CUDNN_HOME})
  endif()

  include(cuDNN)
endif()

if(onnxruntime_USE_SNPE)
  include(external/find_snpe.cmake)
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES ${SNPE_NN_LIBS})
endif()

FILE(TO_NATIVE_PATH ${CMAKE_BINARY_DIR} ORT_BINARY_DIR)
FILE(TO_NATIVE_PATH ${PROJECT_SOURCE_DIR} ORT_SOURCE_DIR)

message(STATUS "Finished fetching external dependencies")
