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

Optional query parameter:

- `?layout=1` to pass `-layout` to `pdftotext`.
