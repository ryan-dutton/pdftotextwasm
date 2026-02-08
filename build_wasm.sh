#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POPPLER_DIR="${ROOT_DIR}/poppler"
BUILD_WEB_DIR="${ROOT_DIR}/build-wasm"
BUILD_WORKER_DIR="${ROOT_DIR}/build-wasm-worker"
EM_CACHE_DIR="${ROOT_DIR}/.emcache"
WEB_DIR="${ROOT_DIR}/web"
WORKER_DIR="${ROOT_DIR}/worker"

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

mkdir -p "${BUILD_WEB_DIR}" "${BUILD_WORKER_DIR}" "${WEB_DIR}" "${WORKER_DIR}"

EM_CACHE="${EM_CACHE_DIR}" embuilder build freetype zlib

if [[ ! -f "${EM_CACHE_DIR}/sysroot/include/freetype2/ft2build.h" ]] || \
   [[ ! -f "${EM_CACHE_DIR}/sysroot/lib/wasm32-emscripten/libfreetype.a" ]] || \
   [[ ! -f "${EM_CACHE_DIR}/sysroot/lib/wasm32-emscripten/libz.a" ]]; then
  echo "error: Emscripten ports were not prepared in ${EM_CACHE_DIR}/sysroot." >&2
  echo "hint: ensure network access for embuilder, use one emsdk in PATH, then rerun ./build_wasm.sh." >&2
  exit 1
fi

COMMON_CMAKE_ARGS=(
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_SHARED_LIBS=OFF
  -DENABLE_UTILS=ON
  -DENABLE_CPP=OFF
  -DENABLE_GLIB=OFF
  -DENABLE_QT5=OFF
  -DENABLE_QT6=OFF
  -DBUILD_GTK_TESTS=OFF
  -DBUILD_QT5_TESTS=OFF
  -DBUILD_QT6_TESTS=OFF
  -DBUILD_CPP_TESTS=OFF
  -DBUILD_MANUAL_TESTS=OFF
  -DENABLE_BOOST=OFF
  -DENABLE_LIBTIFF=OFF
  -DENABLE_NSS3=OFF
  -DENABLE_GPGME=OFF
  -DENABLE_LIBCURL=OFF
  -DENABLE_LCMS=OFF
  -DENABLE_LIBOPENJPEG=none
  -DENABLE_DCTDECODER=none
  -DFONT_CONFIGURATION=generic
  -DRUN_GPERF_IF_PRESENT=OFF
  -DFREETYPE_LIBRARY="${EM_CACHE_DIR}/sysroot/lib/wasm32-emscripten/libfreetype.a"
  -DFREETYPE_INCLUDE_DIRS="${EM_CACHE_DIR}/sysroot/include/freetype2"
  -DZLIB_LIBRARY="${EM_CACHE_DIR}/sysroot/lib/wasm32-emscripten/libz.a"
  -DZLIB_INCLUDE_DIR="${EM_CACHE_DIR}/sysroot/include"
)

configure_and_build() {
  local build_dir="$1"
  local linker_flags="$2"
  pushd "${build_dir}" >/dev/null

  # Avoid stale toolchain/compiler paths when switching emsdk installs.
  rm -f CMakeCache.txt
  rm -rf CMakeFiles

  EM_CACHE="${EM_CACHE_DIR}" emcmake cmake "${POPPLER_DIR}" -G Ninja \
    "${COMMON_CMAKE_ARGS[@]}" \
    "-DCMAKE_EXE_LINKER_FLAGS=${linker_flags}"

  EM_CACHE="${EM_CACHE_DIR}" ninja pdftotext
  popd >/dev/null
}

WEB_LINK_FLAGS="-sEXPORTED_RUNTIME_METHODS=['FS','callMain'] -sALLOW_MEMORY_GROWTH=1"
WORKER_LINK_FLAGS="-sEXPORTED_RUNTIME_METHODS=['FS','callMain'] -sALLOW_MEMORY_GROWTH=1 -sENVIRONMENT=worker -sMODULARIZE=1 -sEXPORT_ES6=1 -sINVOKE_RUN=0 -sEXPORT_NAME=createPdftotextModule"

configure_and_build "${BUILD_WEB_DIR}" "${WEB_LINK_FLAGS}"
configure_and_build "${BUILD_WORKER_DIR}" "${WORKER_LINK_FLAGS}"

cp -f "${BUILD_WEB_DIR}/utils/pdftotext.js" "${WEB_DIR}/pdftotext.js"
cp -f "${BUILD_WEB_DIR}/utils/pdftotext.wasm" "${WEB_DIR}/pdftotext.wasm"
cp -f "${BUILD_WORKER_DIR}/utils/pdftotext.js" "${WORKER_DIR}/pdftotext-worker.js"
cp -f "${BUILD_WORKER_DIR}/utils/pdftotext.wasm" "${WORKER_DIR}/pdftotext-worker.wasm"

# Workerd may not expose self.location; guard Emscripten's worker path probe.
perl -0pi -e 's/scriptDirectory=self\.location\.href/scriptDirectory=(typeof self!="undefined"&&self.location&&self.location.href)?self.location.href:""/g' "${WORKER_DIR}/pdftotext-worker.js"

echo "Built browser artifacts:"
echo "  ${WEB_DIR}/pdftotext.js"
echo "  ${WEB_DIR}/pdftotext.wasm"
echo "Built Cloudflare Worker artifacts:"
echo "  ${WORKER_DIR}/pdftotext-worker.js"
echo "  ${WORKER_DIR}/pdftotext-worker.wasm"
