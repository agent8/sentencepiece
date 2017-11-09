#!/bin/bash
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
# Builds protobuf 3 for iOS.

set -e

if [[ -n MACOSX_DEPLOYMENT_TARGET ]]; then
    export MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)
fi

SCRIPT_DIR=$(dirname $0)

ARCHS="ARMV7 ARMV7S ARM64 I386 X86_64"

USAGE="usage: compile_ios.sh [-A architecture] [-P protoc] [-L protobuf_lib] [-F protobuf_cxxflags]

A script to build protobuf for ios.
This script can only be run on MacOS host platforms.

Options:
-A architecture
Target platforms to compile. The default is: $ARCHS.
-P protoc
Host protoc path. The default is: protoc
-L protobuf_lib
Target protobuf lib to link. Must provide for cross compiling.
-F protobuf_cxxflags
Target protobuf cxxflags deliverd to compiler."

while
  ARG="${1-}"
  case "$ARG" in
  -*)  case "$ARG" in -*A*) ARCHS="${2?"$USAGE"}"; shift; esac
       case "$ARG" in -*P*) PROTOC="${2?"$USAGE"}"; shift; esac
       case "$ARG" in -*L*) PROTOBUF_LIBS="${2?"$USAGE"}"; shift; esac
       case "$ARG" in -*F*) PROTOBUF_CFLAGS="${2?"$USAGE"}"; shift; esac
       case "$ARG" in -*[!APLF]*) echo "$USAGE" >&2; exit 2;; esac;;
  "")  break;;
  *)   echo "$USAGE" >&2; exit 2;;
  esac
do
  shift
done

HOST_PROTOBUF="/Users/resec/edo/tensorflow/tensorflow/contrib/makefile/gen/protobuf-host"
PROTOC="$HOST_PROTOBUF/bin/protoc"
PROTOBUF_CFLAGS="-I$HOST_PROTOBUF/include"
PROTOBUF_LIBS="/Users/resec/edo/tensorflow/tensorflow/contrib/makefile/gen/protobuf_ios/lib"

GENDIR=$(pwd)/gen/ios/
LIBDIR=${GENDIR}lib
mkdir -p ${LIBDIR}

OSX_VERSION="darwin14.0.0"

IPHONEOS_PLATFORM=$(xcrun --sdk iphoneos --show-sdk-platform-path)
IPHONEOS_SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_PLATFORM=$(xcrun --sdk iphonesimulator --show-sdk-platform-path)
IPHONESIMULATOR_SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
MIN_SDK_VERSION=8.0

CXXFLAGS="-Os -std=c++11 -Wall"

./autogen.sh
if [ $? -ne 0 ]
then
  echo "./autogen.sh command failed."
  exit 1
fi

for ARCH in `echo "${ARCHS}" | tr "[:upper:]" "[:lower:]"`; do
  case "$ARCH" in
  i386|x86_64)
    ARCH_PREFIX="${LIBDIR}/iossim_${ARCH}"
    ARCH_SYSROOT="${IPHONESIMULATOR_SYSROOT}"
    ARCH_MIN_SDK_VERSION="-mios-simulator-version-min=${MIN_SDK_VERSION}"
    ARCH_LDFLAGS= #"-L${ARCH_SYSROOT}/usr/lib"
    ;;
  *)
    ARCH_PREFIX="${LIBDIR}/ios_${ARCH}"
    ARCH_SYSROOT="${IPHONEOS_SYSROOT}"
    ARCH_MIN_SDK_VERSION="-miphoneos-version-min=${MIN_SDK_VERSION}"
    ARCH_LDFLAGS=
    ;;
  esac

  case "$ARCH" in
  arm64)
    ARCH_HOST="arm";;
  *)
    ARCH_HOST="${ARCH}-apple-${OSX_VERSION}";;
  esac

  HOST_PROTOBUF="/Users/resec/edo/tensorflow/tensorflow/contrib/makefile/gen/protobuf-host"
  TARGET_PROTOBUF="/Users/resec/edo/tensorflow/tensorflow/contrib/makefile/gen/protobuf_ios"
  PROTOC="$HOST_PROTOBUF/bin/protoc"
  PROTOBUF_CFLAGS="-I$HOST_PROTOBUF/include"
  PROTOBUF_LIBS="-L$TARGET_PROTOBUF/lib -lprotobuf"

  ./configure \
--prefix="${ARCH_PREFIX}" \
--exec-prefix="${ARCH_PREFIX}" \
"ARCH=${ARCH}" \
"MIN_SDK_VERSION=${MIN_SDK_VERSION}" \
"SYSROOT=${ARCH_SYSROOT}" \
"ARCH_LDFLAGS=${ARCH_LDFLAGS}" \
"PROTOC=${PROTOC}" \
"PROTOBUF_CFLAGS=${PROTOBUF_CFLAGS}" \
"PROTOBUF_LIBS=${PROTOBUF_LIBS}"

  make clean

  rm -rf $ARCH_PREFIX
  
  make -j"${JOB_COUNT}"
  if [ $? -ne 0 ]; then
    echo "${ARCH} compilation failed."
    exit 1
  fi
  make install
  
  ARCH_LIBS="${ARCH_LIBS} ${ARCH_PREFIX}/lib/libsentencepiece.a"
done

echo ${ARCH_LIBS}

lipo \
${ARCH_LIBS} \
-create \
-output ${LIBDIR}/libsentencepiece.a
