# pdftotext (Poppler) in Browser via WASM

This project builds Poppler's `pdftotext` command to WebAssembly using Emscripten and provides a browser UI for PDF upload and text extraction.

## What is included

- `build_wasm.sh`: reproducible build script for Poppler + Emscripten.
- `web/index.html`: upload UI that runs `pdftotext` inside browser WASM.
- `web/pdftotext.js` and `web/pdftotext.wasm`: generated artifacts.

## Run locally

Serve the `web/` folder from any static server (required for loading `.wasm`). Example:

```bash
cd web
python3 -m http.server 8000
```

Then open:

- `http://localhost:8000`

## Rebuild WASM

Make sure Emscripten is loaded in your shell first, then run:

```bash
./build_wasm.sh
```

The script outputs fresh artifacts into `web/`.

## Notes

- Build is minimal and intentionally disables some decoders (JPEG/JPX/libopenjpeg/libjpeg) to reduce dependency complexity.
- For best extraction fidelity on image-heavy PDFs, you can extend the build to include more codecs.
- Poppler is GPL-licensed. If you distribute these artifacts, publish corresponding source + build scripts and license notices.
