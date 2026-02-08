import createPdftotextModule from "./pdftotext-worker.js";
import pdftotextWasmModule from "./pdftotext-worker.wasm";

let modulePromise;
let runQueue = Promise.resolve();
let activeRunLogs = null;

function getModule() {
  if (!modulePromise) {
    modulePromise = createPdftotextModule({
      noInitialRun: true,
      instantiateWasm(imports, receiveInstance) {
        const instance = new WebAssembly.Instance(pdftotextWasmModule, imports);
        receiveInstance(instance, pdftotextWasmModule);
        return instance.exports;
      },
      print(text) {
        if (activeRunLogs) {
          activeRunLogs.stdout.push(String(text));
        }
      },
      printErr(text) {
        if (activeRunLogs) {
          activeRunLogs.stderr.push(String(text));
        }
      },
    });
  }
  return modulePromise;
}

function withExclusiveModuleRun(work) {
  const run = runQueue.then(async () => work(await getModule()));
  runQueue = run.catch(() => {});
  return run;
}

function safeUnlink(fs, path) {
  try {
    fs.unlink(path);
  } catch (_) {
  }
}

function ensureTmpDir(fs) {
  try {
    fs.mkdir("/tmp");
  } catch (_) {
  }
}

export default {
  async fetch(request) {
    if (request.method !== "POST") {
      return new Response("POST raw PDF bytes to this endpoint.", { status: 405 });
    }

    const pdfBytes = new Uint8Array(await request.arrayBuffer());
    if (pdfBytes.byteLength === 0) {
      return new Response("Request body is empty.", { status: 400 });
    }
    const looksLikePdf = pdfBytes.byteLength >= 5 &&
      pdfBytes[0] === 0x25 &&
      pdfBytes[1] === 0x50 &&
      pdfBytes[2] === 0x44 &&
      pdfBytes[3] === 0x46 &&
      pdfBytes[4] === 0x2d;
    if (!looksLikePdf) {
      return new Response("Request body does not look like a PDF (%PDF- header missing).", { status: 400 });
    }

    const url = new URL(request.url);
    const keepLayout = url.searchParams.get("layout") === "1";

    try {
      const text = await withExclusiveModuleRun((mod) => {
        const id = crypto.randomUUID();
        const inPath = `/tmp/${id}.pdf`;
        const outPath = `/tmp/${id}.txt`;
        const runLogs = { stdout: [], stderr: [] };

        ensureTmpDir(mod.FS);
        activeRunLogs = runLogs;
        try {
          safeUnlink(mod.FS, inPath);
          safeUnlink(mod.FS, outPath);

          mod.FS.writeFile(inPath, pdfBytes);

          const args = [];
          if (keepLayout) {
            args.push("-layout");
          }
          args.push(inPath, outPath);

          const rc = mod.callMain(args);
          if (rc !== 0) {
            const stderr = runLogs.stderr.join("\n").trim();
            if (stderr) {
              throw new Error(`pdftotext exited with code ${rc}: ${stderr}`);
            }
            throw new Error(`pdftotext exited with code ${rc}`);
          }

          return mod.FS.readFile(outPath, { encoding: "utf8" });
        } finally {
          activeRunLogs = null;
          safeUnlink(mod.FS, inPath);
          safeUnlink(mod.FS, outPath);
        }
      });

      return new Response(text, {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    } catch (err) {
      return new Response(`Extraction failed: ${String(err)}`, { status: 500 });
    }
  },
};
