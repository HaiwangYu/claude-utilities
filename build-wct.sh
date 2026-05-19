#!/usr/bin/env bash
# Clone and build wire-cell-toolkit for either a reference, PR branch, or PR merged into a reference.
# Usage: ./build-wct.sh <ref|pr|merge-pr> <tag|master|PR_number> <src_dir> <install_dir> [base_ref]
set -euo pipefail

MODE="$1"     # "ref", "pr", or "merge-pr"
TARGET="$2"   # tag/master for ref mode; PR number for pr/merge-pr mode
SRC_DIR="$3"
INSTALL_DIR="$4"
BASE_REF="${5:-}"

WCT_REPO="https://github.com/WireCell/wire-cell-toolkit"

if [[ -d "$SRC_DIR" ]]; then
    echo "Removing existing source dir: $SRC_DIR"
    rm -rf "$SRC_DIR"
fi

echo "Cloning $WCT_REPO -> $SRC_DIR"
git clone "$WCT_REPO" "$SRC_DIR"

cd "$SRC_DIR"

if [[ "$MODE" == "ref" ]]; then
    echo "Checking out reference: $TARGET"
    git checkout "$TARGET"
elif [[ "$MODE" == "pr" ]]; then
    echo "Fetching PR #$TARGET"
    git fetch origin "pull/${TARGET}/head"
    git checkout FETCH_HEAD
elif [[ "$MODE" == "merge-pr" ]]; then
    if [[ -z "$BASE_REF" ]]; then
        echo "ERROR: merge-pr mode requires a base reference as the fifth argument" >&2
        exit 1
    fi
    echo "Checking out reference base: $BASE_REF"
    git checkout "$BASE_REF"
    echo "Fetching PR #$TARGET"
    git fetch origin "pull/${TARGET}/head"
    echo "Merging PR #$TARGET into $BASE_REF"
    git -c user.name="wct-ci" -c user.email="wct-ci@example.invalid" \
        merge --no-edit FETCH_HEAD
else
    echo "ERROR: mode must be 'ref', 'pr', or 'merge-pr'" >&2
    exit 1
fi

echo "Configuring (compiler + prefix)..."
env CC=gcc CXX=g++ FC=gfortran \
./wcb configure \
    --build-debug="-O3 -g -fno-omit-frame-pointer" \
    --with-tbb="$TBBROOT" \
    --with-jsoncpp="$JSONCPP_FQ_DIR" \
    --with-jsonnet-include="$GOJSONNET_FQ_DIR/include" \
    --with-jsonnet-lib="$GOJSONNET_FQ_DIR/lib" \
    --with-eigen-include="$EIGEN_DIR/include/eigen3/" \
    --with-root="$ROOTSYS" \
    --with-fftw="$FFTW_FQ_DIR" \
    --with-fftw-include="$FFTW_INC" \
    --with-fftw-lib="$FFTW_LIBRARY" \
    --with-fftwthreads="$FFTW_FQ_DIR" \
    --boost-includes="$BOOST_INC" \
    --boost-libs="$BOOST_LIB" \
    --boost-mt \
    --with-hdf5="$HDF5_FQ_DIR" \
    --with-spdlog-include="$SPDLOG_INC" \
    --with-spdlog-lib="$SPDLOG_LIB" \
    --with-protobuf-include="$PROTOBUF_INC/" \
    --with-protobuf-lib="$PROTOBUF_LIB" \
    --with-grpc="$GRPC_FQ_DIR" \
    --with-grpc-include="$GRPC_INC" \
    --with-grpc-lib="$GRPC_LIB" \
    --with-triton-include="$TRITON_INC" \
    --with-triton-lib="$TRITON_LIB" \
    --with-libtorch="$LIBTORCH_FQ_DIR/" \
    --with-libtorch-include="$LIBTORCH_FQ_DIR/include,$LIBTORCH_FQ_DIR/include/torch/csrc/api/include" \
    --with-libtorch-libs torch,torch_cpu,c10 \
    --prefix="$INSTALL_DIR"

echo "Building and installing -> $INSTALL_DIR ..."
./wcb -p --notests build install 2>&1 | tee build.log

echo "Build complete: $SRC_DIR  (installed to $INSTALL_DIR)"
