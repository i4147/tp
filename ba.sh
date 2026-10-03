#!/bin/bash
# Exit script immediately if any individual step crashes
set -e

echo "=== [1/5] Preparing Host Architecture Emulation Engine ==="
# Setup emulation layer for foreign arm/32-bit execution paths
sudo docker run --rm --privileged aptman/qus -s -- -p arm aarch64

echo "=== [2/5] Creating local target workspace ==="
mkdir -p $(pwd)/output_wheel

echo "=== [3/5] Launching Termux ARM32 Isolation Build Engine ==="
sudo docker run --rm \
  --privileged \
  --security-opt seccomp:unconfined \
  -v "$(pwd)/output_wheel:/output" \
  ghcr.io/termux-user-repository/termux-docker:arm \
  /entrypoint_root.sh bash -c '
    set -e
    echo "=== Inside Sandbox: Updating Termux Mirror Indexes ==="
    pkg update -y

    echo "=== Inside Sandbox: Installing Toolchains & Library Dependencies ==="
    # Shared tools
    pkg install -y build-essential clang pkg-config ninja tuple-repo git cmake patchelf binutils

    # Matplotlib & Pandas headers
    pkg install -y freetype freetype-dev libpng libpng-dev fftw libzmq libzmq-dev libopenblas

    # PyMuPDF engine corequisites 
    pkg install -y mupdf mupdf-static swig

    # Core python installation 
    pkg install -y python python-pip

    echo "=== Inside Sandbox: Upgrading Foundation Pip Tools ==="
    pip install --upgrade pip setuptools wheel cython packaging pyproject_metadata

    echo "=== Inside Sandbox: Pre-building Numpy Base Wheel ==="
    # Essential for both matplotlib and pandas to compile natively
    LDFLAGS="-lpython3.12" pip wheel numpy --wheel-dir=/output
    pip install --no-index --find-links=/output numpy

    echo "=== Inside Sandbox: Setting Base Compiler Path Layouts ==="
    export CFLAGS="-I$PREFIX/include/freetype2 -I$PREFIX/include -Wno-deprecated-declarations -Wno-unreachable-code"
    export CPPFLAGS=$CFLAGS
    export LDFLAGS="-lm -lcompiler_rt -L$PREFIX/lib -lpython3.12"

    echo "=== Inside Sandbox: 1. Compiling Matplotlib Wheel Target ==="
    pip wheel matplotlib --wheel-dir=/output

    echo "=== Inside Sandbox: 2. Compiling Pandas Wheel Target ==="
    pip wheel pandas --wheel-dir=/output --no-build-isolation

    echo "=== Inside Sandbox: 3. Compiling Grpcio Wheel Target ==="
    # Injection of specific Android API targets to bypass C++ mapping crashes
    export GRPC_PYTHON_BUILD_WITH_CYTHON=1
    export GRPC_PYTHON_CFLAGS="-U__ANDROID_API__ -D__ANDROID_API__=24 -include unistd.h"
    CFLAGS="$CFLAGS $GRPC_PYTHON_CFLAGS" CPPFLAGS="$CPPFLAGS $GRPC_PYTHON_CFLAGS" \
    pip wheel grpcio --wheel-dir=/output

    echo "=== Inside Sandbox: 4. Compiling PyMuPDF Wheel Target ==="
    # Direct setup bypass variables ensuring it links to system mupdf package instead of fetching musl-targets
    export PYMUPDF_SETUP_MUPDF_BUILD=0
    pip wheel pymupdf --wheel-dir=/output

    echo "=== Inside Sandbox: Completed Pipeline Execution ==="
'

echo "=== [4/5] Checking Build Results ==="
ls -lh $(pwd)/output_wheel

echo "=== [5/5] Execution Finished Successfully ==="
echo "Your 32-bit ARM wheels are saved and ready for export in: $(pwd)/output_wheel/"
