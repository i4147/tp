#!/bin/bash
# Exit script immediately if any individual step crashes
set -e

echo "=== [1/5] Preparing Host Architecture Emulation Engine ==="
# Termux docker relies on QEMU binfmt_misc routing to build foreign architectures on x86_64
sudo docker run --rm --privileged aptman/qus -s -- -p arm aarch64

echo "=== [2/5] Creating local target workspace ==="
mkdir -p $(pwd)/output_wheel

echo "=== [3/5] Launching Termux ARM32 Isolation Build Engine ==="
# We pull down the official 32-bit arm execution sandbox 
# We explicitly set pid_max and pass unconfined options to keep 32-bit multi-threading safe
sudo docker run --rm \
  --privileged \
  --security-opt seccomp:unconfined \
  -v "$(pwd)/output_wheel:/output" \
  ghcr.io/termux-user-repository/termux-docker:arm \
  /entrypoint_root.sh bash -c '
    set -e
    echo "=== Inside Sandbox: Updating Termux Environment ==="
    pkg update -y

    echo "=== Inside Sandbox: Installing Python 3.12 Corequisites & Build Essentials ==="
    # Pinning python package setup configurations
    pkg install -y build-essential clang pkg-config ninja tuple-repo
    pkg install -y freetype freetype-dev libpng libpng-dev fftw libzmq libzmq-dev
    pkg install -y python python-pip

    echo "=== Inside Sandbox: Verifying Sandbox Python Target Version ==="
    python3 --version

    echo "=== Inside Sandbox: Upgrading Foundation Pip Tools ==="
    pip install --upgrade pip setuptools wheel cython

    echo "=== Inside Sandbox: Compiling Dependency Matrix (Numpy) ==="
    pip install numpy

    echo "=== Inside Sandbox: Binding Environment Compilation Pointers ==="
    export CFLAGS="-I$PREFIX/include/freetype2 -I$PREFIX/include"
    export CPPFLAGS=$CFLAGS
    export LDFLAGS="-lm -lcompiler_rt -L$PREFIX/lib"

    echo "=== Inside Sandbox: Compiling Matplotlib Wheel Target ==="
    # Forces pip to output a universal binary wheel structure instead of immediate local install
    pip wheel matplotlib --wheel-dir=/output

    echo "=== Inside Sandbox: Done building! ==="
'

echo "=== [4/5] Checking Build Results ==="
ls -lh $(pwd)/output_wheel

echo "=== [5/5] Execution Finished Successfully ==="
echo "Your wheel (.whl) target file is saved and ready for export in: $(pwd)/output_wheel/"
