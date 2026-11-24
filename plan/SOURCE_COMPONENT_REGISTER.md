# HLNA v2 — Source Component Register

**Status:** Preliminary source audit; no third-party component approved for integration yet.  
**Baseline date:** 2026-11-24  
**Rule:** All refs below are immutable commits or versioned releases where available. Recheck upstream before implementation.

This register records what was inspected, what was actually found, and the next validation required. Candidate popularity or feature claims are not sufficient for adoption.

## Decision legend

- **Foundation candidate:** may form part of the initial application base after baseline validation.
- **Promising candidate:** worth a focused prototype and comparison.
- **Conditional / defer:** useful capability, but important risks or duplication remain.
- **Do not adopt as-is:** current evidence makes direct adoption inappropriate.
- **Not evaluated:** research still required.

## 1. Jan — desktop foundation

- Repository: https://github.com/janhq/jan
- Evaluation commit: `49a84bdeaebdfc0f36c00f252eb638f516a48432`
- Licence: root Apache-2.0; individual package/assets and dependencies still require verification.
- Status: **Foundation candidate — conditional**.

### Confirmed source areas at the pinned commit

| Path | Purpose | Proposed treatment |
|---|---|---|
| `web-app/src/routes/threads/$threadId.tsx` | Thread/chat route | Retain and rebrand after UI/data-flow audit |
| `web-app/src/hooks/use-chat.ts` | Chat interaction hook | Retain/adapt; preserve cancellation and streaming tests |
| `web-app/src/lib/custom-chat-transport.ts` | Custom chat transport | Retain/adapt for provider-neutral streaming |
| `web-app/src/services/providers/` | Provider service interfaces and implementations | Retain; configure Ollama first |
| `src-tauri/src/core/threads/` | Thread storage and commands | Retain after data isolation and migration audit |
| `src-tauri/src/core/agent/loop.rs` | Shared agent orchestration loop | Strong reuse candidate, but remove Jan-specific assumptions and review permission call sites |
| `src-tauri/src/core/agent/context.rs`, `prompt.rs`, `session.rs`, `transcript.rs`, `events.rs` | Agent context, prompts, budgets, transcripts and event stream | Evaluate as a coherent unit; avoid cherry-picking without its invariants |
| `src-tauri/plugins/tauri-plugin-agent-tools/src/consent.rs` | Tool consent store with once/thread/configuration grants | Reuse concepts/code after threat-model review and HLNA policy changes |
| `src-tauri/plugins/tauri-plugin-agent-tools/src/tools/gate.rs` | Built-in tool gate, escalation and command checks | Candidate for adaptation; independently test bypass resistance |
| `src-tauri/plugins/tauri-plugin-agent-tools/src/tools/sandbox.rs` | Filesystem/shell sandbox helpers | Candidate; audit OS sandbox guarantees and platform coverage |
| `src-tauri/plugins/tauri-plugin-agent-tools/src/permissions.rs` | MCP tool allow/deny policy | Do not use blindly; see security caveat below |
| `src-tauri/plugins/tauri-plugin-rag/src/parser.rs` | Document parsing integration | Inspect supported formats and parser dependencies |
| `src-tauri/plugins/tauri-plugin-vector-db/src/db.rs` | SQLite chunk storage, sqlite-vec loading and linear fallback | Strong initial RAG storage candidate; benchmark before replacing |
| `src-tauri/plugins/tauri-plugin-extensions/` | Extension install/verification/runtime integration | Retain for comparison before adding another plugin runtime |
| `packages/extension-api/src/` | Extension manifests, capabilities, permissions and validation | Strong candidate for HLNA extension contract, subject to security review |
| `src-tauri/src/core/app/paths.rs` | Jan app-data root resolution | Must be adapted; never retain Jan data-path assumptions |

### Important security finding

Jan has useful permission machinery, but it is not safe to treat every call path as deny-by-default automatically. At this pinned commit, `ToolPermissions::allow_all()` is explicitly used in at least one agent orchestration/proxy construction path (`src-tauri/src/core/agent/loop.rs` around line 3196). The permission type itself documents that this helper is permissive. Jan's consent store also supports saved broad MCP grants.

HLNA must trace every construction and execution path, then enforce its own deny-by-default policy centrally. Do not simply reuse Jan defaults or assume the UI approval prompt covers every execution path.

### Critical identity finding

`src-tauri/src/core/app/paths.rs` explicitly resolves `JAN_DATA_ROOT` and documents a legacy migration path that can copy and remove files. HLNA must replace all Jan-specific environment variables, folder names, bundle identifiers and migration/recovery code. It must not read or mutate Jan's profile or HLNA v1.

### Vector search finding

Jan's vector DB plugin already probes and loads a `sqlite-vec` shared extension, uses `vec0` tables when available, and has a linear cosine-similarity fallback. It uses bundled rusqlite with extension loading. This means sqlite-vec is not a new architecture for HLNA: first inspect Jan's existing packaging and loading approach, then decide whether to retain it, improve it or replace it. Avoid introducing a second vector store.

## 2. sherpa-onnx — offline voice

- Repository: https://github.com/k2-fsa/sherpa-onnx
- Rust crate: https://crates.io/crates/sherpa-onnx
- Inspected release: `2.0.3` (2026-11-22)
- Repository licence: Apache-2.0 (verify bundled model and sample licences individually).
- Status: **Promising candidate — prototype required**.

### Evidence inspected
- The Rust crate exposes safe wrappers and RAII cleanup for native resources.
- Rust examples are under `rust-api-examples/examples/`.
- Tauri 2 examples exist under `tauri-examples/`, including microphone streaming ASR.
- The Rust crate's default setup uses static linking and can automatically download matching native libraries at first build.
- The upstream project supports offline ASR, TTS, VAD and multiple other speech functions.

### Proposed use
Prototype streaming microphone ASR and local TTS behind a small HLNA voice interface. Compare latency, CPU/RAM, binary size, cold start, model footprint and language/voice quality.

### Risks / gates
- Native C/C++ and ONNX Runtime footprint may increase package size.
- Model weights have separate licence and redistribution conditions.
- Avoid build-time or runtime downloads without explicit, verified user action.
- Do not bundle large models by default; use a transparent model manager.
- Verify Linux audio capture and device selection in the target desktop environment.

## 3. Apalis — background jobs and workflows

- Repository: https://github.com/apalis-dev/apalis
- Inspected crate: `apalis-workflow` version `1.2.0`
- Licence: MIT.
- Workspace Rust minimum: 1.85; edition 2024.
- Status: **Conditional candidate — prototype only if a real gap exists**.

### Evidence inspected
- `apalis-workflow` uses a graph representation and provides composable sequential/conditional workflow primitives.
- Apalis core provides background task execution, retries, timeout, scheduling, idempotency and storage backends.
- SQLite storage is available in the broader crate ecosystem.

### Proposed use
Consider for durable background job orchestration only if Jan's existing task/agent infrastructure does not meet HLNA requirements. It is not itself a complete end-user workflow designer or automation recorder.

### Risks / gates
- Verify SQLite backend maturity, persistence/recovery semantics and compatibility with the Tauri Tokio runtime.
- Check whether adding Apalis duplicates Jan's existing event/task infrastructure.
- Keep all task actions behind the HLNA permission broker.
- Benchmark idle overhead and concurrency; avoid introducing a worker subsystem without need.

## 4. Extism — Wasm plugin runtime

- Repository: https://github.com/extism/extism
- Licence: BSD-3-Clause.
- Inspected runtime manifest: `runtime/Cargo.toml` at current main during this audit.
- Status: **Conditional / defer**.

### Evidence inspected
- Embeddable Rust runtime using Wasmtime.
- Multi-language plugin development ecosystem.
- Current default Cargo features include HTTP and filesystem registration, in addition to Wasmtime defaults.

### Proposed use
Compare against Jan's existing extension architecture and its Wasmtime-based worker/runtime. Do not add Extism unless it offers a clear compatibility or maintenance advantage.

### Risks / gates
- Adding Extism may duplicate Wasmtime/runtime code already present in Jan.
- Default HTTP and filesystem features are not acceptable as ambient plugin privileges for HLNA; explicitly disable or mediate capabilities.
- Audit host functions, WASI configuration, resource limits, plugin provenance, signatures and cancellation.
- Benchmark binary size and runtime overhead.

## 5. computer-use — desktop automation

- Repository: https://github.com/lindoelio/computer-use
- Inspected package version: `0.4.0`
- Declared licence: `MIT OR Apache-2.0`.
- Declared minimum Rust: 1.91.
- Repository created 2026-10-19; inspected metadata showed very small adoption and limited history.
- Status: **Do not adopt as-is; monitor as a research reference**.

### Evidence inspected
- Rust library and CLI with screenshot, mouse, keyboard, accessibility and browser CDP features.
- Linux X11 support uses X11/XTest-related dependencies.
- Wayland input/capture requires an optional portal feature and native PipeWire/clang build dependencies.
- Its README says a missing policy file defaults to allow (with a built-in deny list).
- Its README documents Linux OCR as unsupported.

### Decision
Despite interesting Linux integration details, this is too new and insufficiently established to be treated as a mature foundation. Its default-allow policy is incompatible with HLNA's intended security posture. Do not copy the whole project or its policy model.

We may inspect narrowly scoped low-level code later if a specific implementation is clearly superior, but only after independent review, tests and a licence/provenance check. Compare it against more established accessibility and desktop automation options before choosing.

## 6. Docling — document processing

- Repository: https://github.com/docling-project/docling
- Inspected repository licence: MIT.
- Primary implementation: Python.
- Status: **Promising capability; optional worker candidate**.

### Evidence inspected
- Broad format support including PDF, DOCX, PPTX, XLSX, HTML, images and audio/video.
- Advanced PDF layout, reading order, table structure and OCR.
- Supports local execution and an optional API server/MCP server.

### Proposed use
Prototype as an optional isolated document-processing worker for complex PDFs, OCR and structured extraction. Do not make its full Python/model stack a mandatory dependency of the desktop application until measured benefits justify it.

### Risks / gates
- Inspect transitive licences and model-weight licences.
- Measure download size, cold start, RAM/CPU and indexing time.
- Ensure models are downloaded only with user consent.
- Keep data local; no remote processing by default.
- Compare against lighter Rust/native parsers and Jan's existing parser before adopting.

## 7. sqlite-vec — vector extension

- Repository: https://github.com/asg017/sqlite-vec
- Licence: Apache-2.0.
- Status: **Do not introduce separately yet**.

### Evidence inspected
- Small C SQLite extension with Rust bindings and no separate database server.
- README explicitly labels it pre-v1 and warns of breaking changes.
- Jan's existing vector DB already loads sqlite-vec dynamically and falls back to linear search.

### Decision
Do not add a new vector database or duplicate integration. Audit the exact sqlite-vec version Jan bundles, its binary provenance, licence, build and packaging. Compare alternatives only if retrieval benchmarks show a concrete problem.

## 8. Immediate research priorities

1. Complete Jan source and runtime audit: exact plugin/agent initialization, all permission call paths, storage migrations, extension sandbox, analytics, updater, CSP and Tauri capabilities.
2. Verify Jan's bundled sqlite-vec binary provenance/version and package licence.
3. Prototype sherpa-onnx microphone ASR/TTS with model licensing and resource measurements.
4. Compare Apalis against Jan's current background task/event facilities before adopting.
5. Compare Extism against Jan's existing extension runtime; likely avoid dual Wasmtime stacks.
6. Research more established Linux desktop automation/accessibility projects and compare Wayland/X11 support.
7. Compare document parsing options with Docling as optional specialist, not assumed default.
8. Add a dated decision record for every accepted/rejected component.

## 9. Current preliminary disposition

| Component | Preliminary decision |
|---|---|
| Jan desktop base | Keep as conditional starting foundation |
| Jan chat/provider/thread code | Reuse after baseline and identity audit |
| Jan agent loop and tools | Reuse selectively; security policy must be redesigned centrally |
| Jan RAG/vector DB | Retain as baseline and benchmark before adding alternatives |
| Jan extension API/runtime | Retain for comparison; avoid duplicate plugin runtimes |
| sherpa-onnx | Prototype |
| Apalis | Defer pending a demonstrated workflow/job gap |
| Extism | Defer pending comparison with Jan's existing Wasmtime stack |
| computer-use | Do not adopt as-is; monitor and compare |
| Docling | Optional worker prototype |
| sqlite-vec | Use existing Jan integration initially; verify bundled binary/version |

**No third-party source has been copied into HLNA v2 by this audit.**
