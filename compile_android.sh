#!/bin/bash -e
# Copyright 2015 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
# Builds Sentencepiece for Android. 

# Pass ANDROID_API_VERSION as an environment variable to support
# a different version of API.
android_api_version="${ANDROID_API_VERSION:-21}"
# Pass cc prefix to set the prefix for cc (e.g. ccache)
cc_prefix="${CC_PREFIX}"

usage() {
  echo "Usage: $(basename "$0") [-a:c]"
  echo "-a [Arch] Architecture of target android [default=armeabi-v7a] \
(supported architecture list: \
arm64-v8a armeabi armeabi-v7a mips mips64 x86 x86_64)"
  echo "-c Clean before building protobuf for target"
  echo "\"NDK_ROOT\" should be defined as an environment variable."
  exit 1
}

SCRIPT_DIR=$(dirname $0)
ARCHITECTURE=armeabi-v7a

# debug options
while getopts "a:c" opt_name; do
  case "$opt_name" in
    a) ARCHITECTURE=$OPTARG;;
    c) clean=true;;
    *) usage;;
  esac
done
shift $((OPTIND - 1))

if [[ -z "${NDK_ROOT}" ]]
then
  echo "You need to pass in the Android NDK location as the environment \
variable"
  echo "e.g. NDK_ROOT=${HOME}/ndk/android-ndk-rXXx ./compile_android.sh"
  exit 1
fi

if [[ -z "${TARGET_PROTOBUF_ROOT}" ]]
then
  echo "TARGET_PROTOBUF_ROOT is not defined"
  exit 1
fi

GENDIR=$(pwd)/gen/android/
LIBDIR=${GENDIR}lib/$ARCHITECTURE
mkdir -p ${LIBDIR}

echo $OSTYPE | grep -q "darwin" && os_type="darwin" || os_type="linux"
if [[ ${ARCHITECTURE} == "arm64-v8a" ]]; then
    toolchain="aarch64-linux-android-4.9"
    sysroot_arch="arm64"
    bin_prefix="aarch64-linux-android"
elif [[ ${ARCHITECTURE} == "armeabi" ]]; then
    toolchain="arm-linux-androideabi-4.9"
    sysroot_arch="arm"
    bin_prefix="arm-linux-androideabi"
elif [[ ${ARCHITECTURE} == "armeabi-v7a" ]]; then
    toolchain="arm-linux-androideabi-4.9"
    sysroot_arch="arm"
    bin_prefix="arm-linux-androideabi"
    march_option="-march=armv7-a"
elif [[ ${ARCHITECTURE} == "mips" ]]; then
    toolchain="mipsel-linux-android-4.9"
    sysroot_arch="mips"
    bin_prefix="mipsel-linux-android"
elif [[ ${ARCHITECTURE} == "mips64" ]]; then
    toolchain="mips64el-linux-android-4.9"
    sysroot_arch="mips64"
    bin_prefix="mips64el-linux-android"
elif [[ ${ARCHITECTURE} == "x86" ]]; then
    toolchain="x86-4.9"
    sysroot_arch="x86"
    bin_prefix="i686-linux-android"
elif [[ ${ARCHITECTURE} == "x86_64" ]]; then
    toolchain="x86_64-4.9"
    sysroot_arch="x86_64"
    bin_prefix="x86_64-linux-android"
else
    echo "architecture ${ARCHITECTURE} is not supported." 1>&2
    usage
    exit 1
fi

echo "Android API Version = ${android_api_version} CC_PREFIX = ${cc_prefix}"

export PATH=\
"${NDK_ROOT}/toolchains/${toolchain}/prebuilt/${os_type}-x86_64/bin:$PATH"
export SYSROOT=\
"${NDK_ROOT}/platforms/android-${android_api_version}/arch-${sysroot_arch}"
export CC="${cc_prefix} ${bin_prefix}-gcc --sysroot ${SYSROOT}"
export CXX="${cc_prefix} ${bin_prefix}-g++ --sysroot ${SYSROOT}"
export CXXSTL=\
"${NDK_ROOT}/sources/cxx-stl/gnu-libstdc++/4.9/libs/${ARCHITECTURE}"
export PROTOBUF_LIBS=\
"-L${TARGET_PROTOBUF_ROOT}/${ARCHITECTURE}/lib -lprotobuf"
export PROTOBUF_CFLAGS=\
"-I${HOST_PROTOBUF_ROOT}/include" 

./autogen.sh
if [ $? -ne 0 ]
then
  echo "./autogen.sh command failed."
  exit 1
fi

./configure \
--host="${bin_prefix}" \
--with-sysroot="${SYSROOT}" \
CFLAGS="${march_option}" \
CXXFLAGS="${march_option} \
-I${NDK_ROOT}/sources/android/support/include \
-I${NDK_ROOT}/sources/cxx-stl/gnu-libstdc++/4.9/include \
-I${NDK_ROOT}/sources/cxx-stl/gnu-libstdc++/4.9/libs/${ARCHITECTURE}/include" \
LDFLAGS="-L${NDK_ROOT}/sources/cxx-stl/gnu-libstdc++/4.9/libs/${ARCHITECTURE}"
LIBS="-llog -lz -lm"

if [ $? -ne 0 ]
then
  echo "./configure command failed."
  exit 1
fi

if [[ ${clean} == true ]]; then
  echo "clean before build"
  make clean
fi

make -j4
if [ $? -ne 0 ]
then
  echo "make command failed."
  exit 1
fi

cp src/.libs/libsentencepiece.a $LIBDIR/libsentencepiece.a

echo "$(basename $0) finished successfully!!!"
