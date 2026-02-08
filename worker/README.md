# Cloudflare Worker Variant

This folder is populated by `../build_wasm.sh` with a Worker-specific Emscripten build:

- `pdftotext-worker.js` (ES module factory)
- `pdftotext-worker.wasm`

It also contains a sample endpoint:

- `sample-endpoint.js`

## Build artifacts

From project root:

```bash
./build_wasm.sh
```

## Use in a Worker project

Copy these files into your Worker app:

- `worker/pdftotext-worker.js`
- `worker/pdftotext-worker.wasm`
- `worker/sample-endpoint.js` (or copy logic from it)

The sample endpoint accepts `POST` PDF bytes and returns extracted text.
It imports `pdftotext-worker.wasm` directly and passes `instantiateWasm` to Emscripten, which avoids the `XMLHttpRequest is not defined` failure in Cloudflare Workers.

Optional query parameter:

- `?layout=1` to pass `-layout` to `pdftotext`.

## If you are not using direct wasm imports

When you initialize the module, prefer providing `wasmBinary` yourself instead of only `locateFile(...)`. If the wasm fetch fails, Emscripten can fall back to sync XHR (not available in Workers).
