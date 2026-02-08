#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POPPLER_DIR="${ROOT_DIR}/poppler"
BUILD_DIR="${ROOT_DIR}/build-wasm"
EM_CACHE_DIR="${ROOT_DIR}/.emcache"
WEB_DIR="${ROOT_DIR}/web"

if ! command -v emcmake >/dev/null 2>&1; then
  echo "error: emcmake not found. Load emsdk first (e.g. 'source <emsdk>/emsdk_env.sh')." >&2
  exit 1
fi

if ! command -v embuilder >/dev/null 2>&1; then
  echo "error: embuilder not found. Load emsdk first (e.g. 'source <emsdk>/emsdk_env.sh')." >&2
  exit 1
fi

if [[ ! -d "${POPPLER_DIR}" ]]; then
  git clone --depth 1 https://gitlab.freedesktop.org/poppler/poppler.git "${POPPLER_DIR}"
fi

if ! grep -q "Emscripten's current libc++ has stricter C++23 behavior" "${POPPLER_DIR}/CMakeLists.txt"; then
  perl -0pi -e 's/set\(CMAKE_CXX_STANDARD 23\)/if(EMSCRIPTEN)\n  # Emscripten\x27s current libc\+\+ has stricter C\+\+23 behavior that breaks\n  # several forward-declared unique_ptr usages in Poppler.\n  set(CMAKE_CXX_STANDARD 20)\nelse()\n  set(CMAKE_CXX_STANDARD 23)\nendif()/s' "${POPPLER_DIR}/CMakeLists.txt"
fi

mkdir -p "${BUILD_DIR}" "${WEB_DIR}"

EM_CACHE="${EM_CACHE_DIR}" embuilder build freetype zlib

pushd "${BUILD_DIR}" >/dev/null

EM_CACHE="${EM_CACHE_DIR}" emcmake cmake "${POPPLER_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_UTILS=ON \
  -DENABLE_CPP=OFF \
  -DENABLE_GLIB=OFF \
  -DENABLE_QT5=OFF \
  -DENABLE_QT6=OFF \
  -DBUILD_GTK_TESTS=OFF \
  -DBUILD_QT5_TESTS=OFF \
  -DBUILD_QT6_TESTS=OFF \
  -DBUILD_CPP_TESTS=OFF \
  -DBUILD_MANUAL_TESTS=OFF \
  -DENABLE_BOOST=OFF \
  -DENABLE_LIBTIFF=OFF \
  -DENABLE_NSS3=OFF \
  -DENABLE_GPGME=OFF \
  -DENABLE_LIBCURL=OFF \
  -DENABLE_LCMS=OFF \
  -DENABLE_LIBOPENJPEG=none \
  -DENABLE_DCTDECODER=none \
  -DFONT_CONFIGURATION=generic \
  -DRUN_GPERF_IF_PRESENT=OFF \
  -DFREETYPE_LIBRARY="${EM_CACHE_DIR}/sysroot/lib/wasm32-emscripten/libfreetype.a" \
  -DFREETYPE_INCLUDE_DIRS="${EM_CACHE_DIR}/sysroot/include/freetype2" \
  -DZLIB_LIBRARY="${EM_CACHE_DIR}/sysroot/lib/wasm32-emscripten/libz.a" \
  -DZLIB_INCLUDE_DIR="${EM_CACHE_DIR}/sysroot/include" \
  "-DCMAKE_EXE_LINKER_FLAGS=-sEXPORTED_RUNTIME_METHODS=['FS','callMain'] -sALLOW_MEMORY_GROWTH=1"

EM_CACHE="${EM_CACHE_DIR}" ninja pdftotext

cp -f "${BUILD_DIR}/utils/pdftotext.js" "${WEB_DIR}/pdftotext.js"
cp -f "${BUILD_DIR}/utils/pdftotext.wasm" "${WEB_DIR}/pdftotext.wasm"

popd >/dev/null

echo "Built and copied: ${WEB_DIR}/pdftotext.js and ${WEB_DIR}/pdftotext.wasm"
