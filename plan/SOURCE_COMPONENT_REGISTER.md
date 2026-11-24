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

Jan has useful permission machinery, but it is not safe to treat every call path as deny-by-default automatically. The shared orchestration loop receives a ToolPermissions value; it does not itself construct ToolPermissions::allow_all() at this pinned commit. The permissive constructor exists in the permission module and is used in tests. Every caller and surface still needs separate tracing. Jan's consent store also supports saved MCP grants.

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
Compare against Jan's existing JavaScript Web Worker extension architecture. Jan does not use Wasmtime for this runtime at the pinned revision. Do not add Extism unless it offers a clear compatibility or maintenance advantage.

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


## 9. Research update — 2026-11-24

This section adds independent source research performed after the preliminary audit. Findings are tied to official repositories, release notes or project documentation where possible. Performance claims made by upstream projects remain unverified until reproduced on the HLNA target machine.

### 9.1 computer-use-linux — leading Linux desktop interaction candidate

- Repository: https://github.com/agent-sh/computer-use-linux
- Crate: https://crates.io/crates/computer-use-linux
- Latest crate/package version observed in the current source and registry: 0.7.60 (2026-11-22). The GitHub Releases page surfaced only tag v0.7.31; resolve the source-tag/registry provenance discrepancy before pinning.
- Licence: MIT (verify all packaged assets and dependencies at the exact pinned revision).
- Security policy: https://github.com/agent-sh/computer-use-linux/blob/main/SECURITY.md
- Status: **Promising prototype candidate; not approved for direct agent exposure or unrestricted integration.**

This is a substantially stronger candidate than the previously listed `lindoelio/computer-use`. The project describes native Linux desktop control using AT-SPI accessibility trees, screenshots, compositor-aware window targeting and input across GNOME, KDE/KWin, Hyprland, niri, COSMIC, i3, Sway, labwc/wlroots and X11. It is a Rust project extracted from the Linux Codex Desktop implementation and is published as a standalone crate/MCP server.

Official project documentation:
- https://github.com/agent-sh/computer-use-linux
- https://docs.rs/crate/computer-use-linux/latest
- https://github.com/agent-sh/computer-use-linux/releases

Important caveats:
- Support is compositor- and session-dependent. The README's own matrix documents cases where a desktop can be observed but some input or window operations are unavailable. Do not describe it as universal Wayland automation.
- It can observe and mutate the user's real desktop. Screenshots and accessibility text may contain private information. Observation and mutation need separate permissions and visible user control.
- It exposes an MCP server and CLI. Do not make the full tool set directly available to an autonomous agent without an HLNA policy gate.
- Its HTTP MCP mode is optional and documented as unencrypted; prefer stdio/local process integration. Never expose it on a network without a separately reviewed secure transport.
- The project states that shell execution is optional and disabled unless explicitly enabled. HLNA should keep shell execution out of this integration.
- The repository security policy says only the latest release is supported for security updates. Maintain a regular update review.
- The initial registry/release-page discrepancy is resolved at source level: commit 31d34d65becd36a5796c5cc13c01fa4fce62c46a contains Cargo/package version 0.7.60 and the changelog links the v0.7.60 tag comparison. Verify the published crate archive checksum against this exact source before adoption.

Proposed HLNA approach:
1. Prototype the latest verifiable source revision on the actual target desktop session.
2. Evaluate source integration versus spawning it as a supervised local child process.
3. Keep its low-level desktop backend behind an HLNA-owned broker. The broker separately authorises observation, screenshots, window focus, typing, clicks and other mutations.
4. Add a visible activity indicator, per-session grants, immediate stop/revoke, action audit and strict target scoping.
5. Reject ambiguous/stale targets and never replay an action after dispatch.
6. Keep desktop automation disabled until the user explicitly enables it.

### 9.2 docling.rs — Rust document pipeline candidate

- Repository: https://github.com/docling-project/docling.rs
- Latest release observed: `v2.86.14`, 2026-11-21.
- Licence: MIT, with a separately identified Adobe CID-to-Unicode mapping resource under BSD-3-Clause.
- Status: **Promising specialist prototype; compare with Jan's current parser and Python Docling.**

The project is a Rust port of Docling and advertises PDF, Office, HTML, image/scanned-document and audio/video ingestion. Its workspace includes a core document model, format converters, PDF/ONNX layout and OCR pipeline, CLI, language bindings and optional RAG subsystem. It offers a Rust library/CLI route that may avoid making a full Python/PyTorch stack mandatory.

Official references:
- https://github.com/docling-project/docling.rs
- https://github.com/docling-project/docling.rs/releases
- https://github.com/docling-project/docling.rs/blob/master/Cargo.toml
- https://github.com/docling-project/docling.rs/blob/master/README.md

Proposed use:
- Benchmark as a document-ingestion worker or Rust library for complex PDFs, tables, OCR and Office documents.
- Keep model downloads separate, explicit and user-controlled.
- Compare it against Jan's existing parser, lighter format-specific parsers and upstream Python Docling.
- Reproduce upstream performance and quality claims using the same documents and hardware.
- Preserve the BSD-3-Clause notice for Adobe mapping resources in redistributed builds; audit every ONNX model and font independently.

Risks:
- The compact binary/release asset size is not the complete installed footprint when OCR/layout models are downloaded.
- PDF/image processing may have meaningful RAM and CPU cost. It should not run continuously or be a mandatory dependency for simple text documents.
- A separate RAG subsystem inside docling.rs could duplicate Jan's vector database and embedding pipeline. Initially use it only for conversion/parsing, then pass normalized output into one chosen HLNA retrieval stack.

### 9.3 sherpa-onnx — voice candidate strengthened

- Repository: https://github.com/k2-fsa/sherpa-onnx
- Release: `v2.0.3`, published 2026-11-22; release signature reported verified.
- Licence: Apache-2.0 for the project; individual model and voice assets have their own terms.
- Rust docs: https://docs.rs/sherpa-onnx/latest/sherpa_onnx/
- Status: **Prototype candidate for offline ASR/VAD/TTS.**

The Rust API provides model-family configuration, stream processing and RAII cleanup; upstream maintains Rust examples and Tauri examples. The default Rust setup uses static linking and may automatically download matching native libraries during the first build. HLNA must not allow hidden/unpinned build-time downloads: pin artifacts, verify checksums and cache dependencies in a reproducible build process.

Release notes for v2.0.3 specifically corrected a PocketTTS model README licence note to CC-BY-4.0 rather than non-commercial. This is a useful reminder that model licences must be tracked independently from the Apache-2.0 code licence.

References:
- https://github.com/k2-fsa/sherpa-onnx/releases/tag/v2.0.3
- https://github.com/k2-fsa/sherpa-onnx/tree/master/rust-api-examples
- https://github.com/k2-fsa/sherpa-onnx/tree/master/tauri-examples

Comparison:
- Evaluate sherpa-onnx as the broad speech toolkit for ASR, VAD and TTS.
- Evaluate whisper-rs/whisper.cpp as a narrower ASR alternative, not a replacement for a full TTS/VAD stack. whisper-rs is Unlicense, but its native build, model quality and hardware path still need review.
- Compare latency, streaming stability, CPU/GPU use, model footprint, language coverage and speech quality. No model should be bundled by default until its licence and size are understood.

### 9.4 Workflow engine comparison — Apalis versus Cloacina

**Apalis**
- Repository: https://github.com/apalis-dev/apalis
- Observed release: `1.2.0` (2026-11-14), MIT.
- SQLite backend: https://github.com/apalis-dev/apalis-sqlite
- Docs: https://docs.rs/apalis/latest/apalis/
- Status: **Strong background-job candidate; workflow layer needs maturity review.**

Apalis provides workers, persistent backends including SQLite, retries, timeouts, scheduling, idempotency, heartbeats and recovery. Its `apalis-workflow` crate is currently shown as `0.1.0-rc.10` in docs.rs, with sequential and DAG workflow primitives. Treat the queue/worker core and workflow subcrate as separate maturity decisions.

**Cloacina**
- Repository: https://github.com/colliery-io/cloacina
- Observed Rust crate: `0.12.0`.
- Licence: Apache-2.0.
- Docs: https://docs.rs/cloacina/latest/cloacina/
- Status: **Promising embedded workflow prototype; not yet selected.**

Cloacina provides embedded Rust workflows with SQLite/PostgreSQL persistence, DAG dependencies, retries, task recovery and event-driven computation graphs. Its architecture appears closer to HLNA's need for durable multi-step workflows than a basic task queue alone.

Provisional comparison:
- Apalis is a good candidate for general-purpose background jobs and worker scheduling.
- Cloacina is a good candidate for durable workflow graphs and recovery.
- Neither is a visual workflow editor, automation recorder or permission system. HLNA would still need a user-facing workflow definition/editor and must route every action through its permission broker.
- Do not add both automatically. Prototype a representative set of jobs and workflows (including process restart, retries, cancellation, pause/resume, idempotency and SQLite contention) and select one engine if it meets the requirements. If Jan's own task infrastructure suffices, select neither.

References:
- https://docs.rs/apalis/latest/apalis/
- https://docs.rs/apalis-workflow/latest/apalis_workflow/
- https://docs.rs/apalis-sqlite/latest/apalis_sqlite/
- https://docs.rs/cloacina/latest/cloacina/
- https://colliery-io.github.io/cloacina/explanation/features/

### 9.5 Extism — retain defer decision

Extism's observed Rust crate version is `1.41.0`. Its default features include HTTP access, HTTP-based module registration, filesystem-based module registration and Wasmtime defaults. Those are not acceptable as ambient extension privileges in HLNA.

Correction from the pinned-source audit: Jan's extension runtime at this revision is JavaScript running in browser Web Workers, not Wasmtime. It creates one blob-backed Worker per extension inside a hidden same-origin frame with a restrictive CSP. Host API calls pass through a permission dispatcher that validates method arguments and checks explicit grants. Network access is mediated by a Rust Tauri plugin; each request re-reads stored grants, the HTTP client has no cookie jar and does not follow redirects, and each redirect hop is checked again by the host. This is useful defense-in-depth, but it is not an OS-process sandbox and does not establish memory/CPU isolation from the WebView engine. Extism would add a separate Wasmtime-backed Wasm runtime, not duplicate an existing Jan Wasmtime runtime. Keep it deferred unless a pinned, reproducible comparison shows a material benefit. If ever prototyped, disable default features and expose only narrowly defined HLNA host functions; no plugin gets ambient filesystem or network access.

References:
- https://docs.rs/crate/extism/latest/features
- https://extism.org/docs/concepts/configuration/

### 9.6 Jan pinned-source audit — confirmed implementation facts

The following were checked directly at Jan commit `49a84bdeaebdfc0f36c00f252eb638f516a48432`:

- Root `LICENSE` is Apache-2.0 and includes a request for attribution in user-facing documentation/materials where appropriate.
- `src-tauri/src/core/agent/loop.rs` accepts a `ToolPermissions` value through `OrchestrationArgs`; it does not itself construct `ToolPermissions::allow_all()` at the pinned revision. The desktop chat tool loop is driven from TypeScript and reaches Rust through `tauri-plugin-agent-tools` IPC. Its `execute_tool` path uses `ToolPermissions::default()` (whose default is `ReadOnly`) and enforces workspace/path checks; the desktop shell is refused unless an enforcing OS jail is available. The permissive `allow_all()` constructor exists in the permission module and is used by tests, so HLNA must still audit every caller and surface rather than infer policy from the shared loop alone.
- `src-tauri/src/core/app/paths.rs` defines `JAN_DATA_ROOT`, Jan data folders and Jan-specific path handling. Replacing only the Tauri bundle identifier is insufficient. Audit all environment variables, folder names, migration commands, backups and recovery paths.
- `src-tauri/plugins/tauri-plugin-vector-db/src/db.rs` stores vector collections below a Jan-specific data path and probes for sqlite-vec, with a linear-search fallback. This supports retaining the existing retrieval storage as the first benchmark baseline rather than adding another vector DB immediately.
- `src-tauri/tauri.conf.json` declares the Jan product name, binary name and `jan.ai.app` identifier. It also lists multiple capability files and a CSP with broad remote connectivity.
- `src-tauri/capabilities/default.json` includes shell spawning, broad HTTP URL scopes, agent tools, updater permissions and other plugins. This must be replaced by explicit HLNA capabilities with minimal per-window permissions.
- Jan's Tauri configuration is a starting point, not a security guarantee. Tauri documentation explicitly states that capabilities do not sandbox unsafe Rust code and that Linux cannot distinguish requests from an embedded iframe and its parent window in the same way as some other platforms.

Pinned source links:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/LICENSE
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/agent/loop.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/app/paths.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-vector-db/src/db.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/capabilities/default.json
- https://v2.tauri.app/security/capabilities/
- https://v2.tauri.app/security/

### 9.7 Updated provisional dispositions

| Component | Updated disposition | Next gate |
|---|---|---|
| Jan pinned desktop foundation | Conditional foundation candidate | Clean unmodified Linux build; identity/network/security audit |
| Jan chat, provider and thread modules | Reuse candidates | Dependency and data-isolation tests |
| Jan agent loop/tools | Selective reuse only | Trace all permission paths; remove permissive defaults |
| Jan vector DB/sqlite-vec | Keep as initial benchmark baseline | Verify binary provenance/version and retrieval quality |
| Jan extension runtime/API | Keep as first extension baseline | Review Wasmtime isolation, grants and lifecycle |
| computer-use-linux | New leading desktop-interaction prototype | Resolve release/tag discrepancy; pin source; test target compositor and permission mediation |
| older lindoelio/computer-use | Do not adopt as primary implementation | May consult only for narrow code if useful |
| sherpa-onnx 2.0.3 | Voice prototype | Reproducible native build and model licence/latency checks |
| whisper-rs | ASR comparison only | Build/quality/resource comparison |
| docling.rs 2.86.14 | Rust document-pipeline prototype | Reproduce PDF/OCR/table benchmarks and audit models/notices |
| Python Docling | Comparison baseline / optional worker | Measure Python and model overhead |
| Cloacina 0.12 | Durable workflow prototype | SQLite restart/recovery/idempotency tests |
| Apalis 1.2 | Background job queue comparison | Compare against Cloacina and Jan task facilities |
| Extism 1.41 | Defer | Demonstrate advantage over Jan runtime; no ambient HTTP/filesystem |
| sqlite-vec standalone addition | Do not add yet | Reconsider only if Jan's existing integration fails benchmarks |

**No candidate in this update is approved for production integration. No third-party source has been copied into the HLNA v2 application tree.**


### 9.8 Desktop foundation comparison — alternatives checked

The Jan choice should be compared against credible, maintained alternatives rather than assumed to be best simply because it was selected first.

| Project | Licence / architecture evidence | Fit for HLNA v2 | Preliminary disposition |
|---|---|---|---|
| [Jan](https://github.com/janhq/jan) | Apache-2.0; Tauri 2, Rust backend, React frontend; existing agent, provider and extension architecture | Closest match to the chosen Rust/Tauri architecture and already has useful app-level functionality | Keep as conditional foundation; build and harden |
| [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) | MIT; Vite/React frontend plus Node/Express server and document collector; desktop and self-hosted modes | Strong feature-rich reference for RAG, document pipelines and agents, but imports a second Node server/collector architecture | Do not replace Jan as foundation without a strong measured reason; inspect focused document/RAG modules if Jan/docling.rs leave a gap |
| [GPT4All](https://github.com/nomic-ai/gpt4all) | MIT; Qt/C++ desktop application and native model/backend stack | Mature local-AI product with useful UX ideas, but a second Qt/C++ desktop foundation and bundled inference stack conflict with the current Tauri/Rust/Ollama-first direction | Reference for UX and local-model management; not initial foundation |
| [Chatbox Community Edition](https://github.com/chatboxai/chatbox) | GPL-3.0; cross-platform desktop client | Useful client UX and provider feature reference; GPL obligations need review against HLNA's eventual distribution/licence, and it does not match the selected Tauri/Rust base | Reference only pending licence/product compatibility |
| [Open WebUI](https://github.com/open-webui/open-webui) | Newer Open WebUI licence includes a branding clause; older contributions through v0.6.5 remain BSD-3 | Powerful web application and ecosystem, but not a native Tauri/Rust foundation; rebranding constraints make newer code unsuitable for a clean HLNA identity unless terms are accepted | Do not use as the foundation; use only for product research or evaluate old code only if a specific need justifies an older baseline |
| [OpenYoke](https://github.com/saicv8/OpenYoke) | MIT; Tauri/Rust, Ollama HTTP integration, lightweight frontend | Architectural match for a simple Ollama client, but current adoption/maintenance evidence is too limited for a full foundation | Small reference for simple Ollama integration and branching-chat UX |
| [Ambient](https://github.com/LukeSutor/ambient) | Tauri/Rust + Next.js, bundled llama.cpp/Vulkan, RustPython and cloud services | Interesting screen-context and agent features, but brings bundled inference and cloud-service assumptions not aligned with Ollama-first/no-telemetry baseline | Feature reference only; no adoption without a separate architecture/licence/security review |

Key references:
- AnythingLLM architecture and MIT licence: https://github.com/Mintplex-Labs/anything-llm and https://github.com/Mintplex-Labs/anything-llm/blob/master/LICENSE
- GPT4All Qt/C++ build and MIT licence: https://github.com/nomic-ai/gpt4all and https://github.com/nomic-ai/gpt4all/blob/main/LICENSE.txt
- Chatbox GPL-3.0: https://github.com/chatboxai/chatbox
- Open WebUI licence history/branding clause: https://docs.openwebui.com/license/
- OpenYoke Tauri/Rust/Ollama architecture: https://github.com/saicv8/OpenYoke
- Ambient Tauri/Rust architecture: https://github.com/LukeSutor/ambient

**Conclusion:** Jan remains the best current starting foundation for HLNA's Tauri 2 + Rust desktop architecture, but only conditionally. AnythingLLM is the strongest broad feature reference for document/RAG workflows; GPT4All is a mature alternative product with a different native stack. The choice must still pass an unmodified baseline build and a focused comparison of required capabilities.


### 9.9 Agent security and build-provenance audit refinement

The pinned-source inspection adds the following verified details and corrections:

1. **Desktop agent execution:** Jan's desktop chat tool loop is TypeScript-driven and calls Rust through tauri-plugin-agent-tools IPC. The Rust execute_tool path uses ToolPermissions::default(), which resolves to PermissionDefault::ReadOnly. It checks workspace and hidden paths. Writes are confined to an ephemeral thread workspace; attached-folder writes are a distinct opt-in. Shell execution is refused unless an enforcing OS jail is available, and desktop escalation is refused. Preserve and test these properties if reusing this module.
2. **Do not conflate agent surfaces:** the shared Rust orchestration loop receives a permissions object; it does not itself call ToolPermissions::allow_all() at the pinned ref. The permissive constructor exists in permissions.rs and is used in tests. CLI and API callers must be traced separately. The earlier register wording that attributed allow_all() to loop.rs is corrected.
3. **Migration isolation:** Jan's app config migration searches Jan legacy locations, copies settings into a canonical location and attempts to remove the legacy copy. HLNA must disable or replace all such recovery/migration code. A new app identifier or storage root alone does not guarantee Jan/v1 data isolation.
4. **WebView and plugin permissions:** the pinned default Tauri capability includes shell spawn/open, broad HTTP scopes, updater and multiple powerful plugins. Tauri CSP allows broad HTTP(S) connections and includes PostHog hostnames; updater endpoints are configured. HLNA must build a minimal capability set and remove analytics/updater/network defaults not explicitly required.
5. **Build provenance:** Jan's binary-download script fetches Bun and uv through floating latest URLs and obtains sqlite-vec assets dynamically. HLNA should pin versions, hashes/signatures and source revisions for all build tools and binary assets; do not copy this dynamic download behavior unchanged.

References:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/permissions.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/app/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/tauri.conf.json
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/capabilities/default.json
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/scripts/download-bin.mjs

### 9.10 Desktop-control package version discrepancy — unresolved

The initial Releases-page result was stale/incomplete. A GitHub source search found the exact v0.7.60 source commit 31d34d65becd36a5796c5cc13c01fa4fce62c46a: Cargo.toml and package.json both declare 0.7.60, and CHANGELOG.md links the v0.7.59...v0.7.60 comparison. This resolves the source-version mapping, although the GitHub Releases listing surfaced only v0.7.31 in the earlier page result. Before adoption, still verify the exact crates.io archive checksum against this commit, release assets and dependency graph. Do not pin a floating latest package.

The project remains a strong Linux desktop-control prototype, but all observation and mutation must be mediated by HLNA's broker. Its on-screen activity indicator is a useful UX/security feature to evaluate. Test the target compositor, portal consent, focus validation, accessibility data exposure, stale-target handling, input correctness and stop/revoke behavior. Never expose its full MCP toolset directly to the model.

References:
- https://github.com/agent-sh/computer-use-linux/releases
- https://github.com/agent-sh/computer-use-linux/security
- https://docs.rs/crate/computer-use-linux/latest


### 9.11 Exact extension-runtime audit — JavaScript Worker, not Wasmtime

At the pinned Jan revision, the runtime architecture is now confirmed:

- `web-app/src/lib/extensions/worker-runtime.ts` creates a blob-backed classic JavaScript Web Worker for each extension inside a hidden same-origin frame. Its worker CSP is `default-src 'none'; script-src 'wasm-unsafe-eval'; worker-src blob:`. This allows WebAssembly compilation but does not imply that the host uses Wasmtime.
- The runtime prelude strips selected globals, while the host dispatcher validates method arguments and checks declared grants. Worker messages are bounded/rate-limited and workers can be terminated.
- Installed extension network access is routed through the Rust `http_fetch` command. Grants are re-read from the registry for each request. The HTTP client has no cookie store and disables automatic redirects. Request methods, headers and body size are constrained; response size and timeout are bounded. The host follows redirects one hop at a time, checking each target against grants. The app's own local API port is refused.
- The Rust HTTP source explicitly documents accepted DNS-rebinding and proxy-configuration risks. The grant checks the URL hostname, not the resolved IP. Requests may use configured environment/system proxies. HLNA must review these choices against its own threat model.
- This Worker is not an OS-process sandbox and does not provide independent OS-enforced memory/CPU isolation. The WebView/browser engine remains trusted. Resource exhaustion, engine compromise, renderer compromise and defects in privileged host APIs remain important risks.
- Extism would add a separate Wasmtime-backed Wasm runtime; it does not duplicate Jan's existing extension runtime. It remains deferred pending a demonstrated need and a minimal, explicit host API.

Pinned source:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/extensions/worker-runtime.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/extensions/dispatcher.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/extensions/host-api.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/http.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/install.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/state.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/permissions.rs


### 9.12 Vector database findings and reuse conditions

The pinned Jan vector database is a practical SQLite baseline with ordinary chunk storage, optional sqlite-vec ANN indexing, and linear cosine-similarity fallback. The source also validates embeddings against empty/non-finite values and handles ANN insert failures without losing the linear record. However, the following must be resolved before production reuse:

1. **Native code loading:** the sqlite-vec loader searches JAN_SQLITE_VEC_PATH, development and executable-relative paths, system directories, and bare library names. Since SQLite extension loading executes native code inside HLNA, use only a bundled, hash-verified, pinned artifact from an application-owned resource path. Do not inherit arbitrary environment/system/bare-name lookup. Disable extension loading after the trusted load where supported.
2. **Delete consistency:** chunks are inserted into both chunks and chunks_vec, but the inspected delete_file and delete_chunks implementations delete only from chunks. Add synchronized deletion and tests for orphan rows, reinsertions, rowid reuse, collection cleanup and restart. Until then, ANN correctness and storage growth need validation.
3. **Embedding identity:** persist model name/revision, vector dimension, tokenizer and chunking version with each collection. Build replacement indexes separately and switch only after successful verification; never silently mix models/dimensions or destroy the only valid index.
4. **Duplicate inference:** project ingestion embeds chunks once to discover dimension and then calls embedTexts again for insertion. Preserve the first result and reuse it. Benchmark the saved inference cost on the target hardware.
5. **Chunking/provenance:** the Rust helper chunks by Unicode character count. HLNA should use the embedding model's tokenizer and preserve page/section metadata through retrieval.
6. **Operational policy:** establish SQLite WAL/busy timeout/checkpoint, backup and concurrent indexing behaviour. Test collection/file deletion and recovery.

Disposition: retain as a correctness/performance benchmark baseline only. Do not add another vector database until these issues are tested and a reproducible retrieval benchmark demonstrates a material need.

References:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-vector-db/src/db.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-vector-db/src/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/extensions/vector-db-extension/src/index.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/extensions/rag-extension/src/index.ts



## 10. Research update — 2026-11-24 (continued)

This update records a deeper pass over extension supply-chain controls, Jan's existing background-task facilities, current workflow libraries, Docling.rs model/build requirements, sherpa-onnx's Rust linking behaviour, and the current computer-use-linux source version. No component is approved for production integration by these findings alone.

### 10.1 Jan extension supply-chain controls — positive finding and remaining gap

The pinned Jan extension implementation has stronger publisher-integrity controls than the earlier summary made explicit:

- A source can be associated with a public key explicitly pinned by the user. Jan ships no universal trust key; the user's pinned key is the trust anchor.
- The index is signed using detached Ed25519 signatures over the exact index bytes. The implementation uses strict signature verification and rejects weak keys/non-canonical signatures.
- Signed indexes have freshness controls: generated timestamps cannot roll back behind the latest accepted index, cannot be too far in the future, and can expire.
- Each indexed extension tarball is pinned by SHA-512 SRI. The downloaded archive is checked against that digest.
- The package manifest's extension ID, version and requested permissions are compared with the signed index listing before consent is presented. This prevents a tarball from silently changing the permission set shown in the catalog.
- Unsigned indexes and local .tgz installation are also supported and must remain visibly distinguishable from keyed/verified sources.
- An optional provenance-attestation URL in the index is displayed as reported by the source; Jan explicitly does not verify that attestation. Do not mistake it for a verified build provenance statement.
- Permission changes on update are represented as a diff and newly requested permissions require consent.

This is a useful baseline for HLNA's extension catalogue and update design. Before reuse, test key rotation, revocation/re-pinning UX, rollback/freshness edge cases, signature and SRI failures, downgrade behaviour, package extraction limits, registry recovery, and whether a compromised already-pinned publisher can ship a malicious but correctly signed extension. A valid signature proves publisher-key continuity and integrity, not that the extension is benign.

Pinned source:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/signature.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/index.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/install.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/docs/src/pages/docs/desktop/extensions/index.mdx

### 10.2 Jan background work — useful agent primitives, not a general durable workflow engine

The pinned Jan source includes real background-agent functionality:

- Cowork has subagent dispatch, task/todo state, and background monitor tools.
- Finished subagent runs are merged by run ID and stored in the Cowork session state sidecar. Cowork session persistence uses the shared thread store and a separate sidecar for non-transcript state.
- Monitor tools run bounded shell checks under the same confinement as the shell tool, with explicit interval/timeout limits. They can continue after a model turn ends and deliver a later system notice to a running or newly started turn.
- The Rust MonitorSet owns in-memory Tokio tasks and active monitor state. The Cowork client has in-memory monitor lanes. The inspected implementation does not establish that active monitor execution survives application-process termination.
- These facilities are useful for agent delegation and short-lived waits, but they are not equivalent to a general-purpose durable, versioned workflow DAG with persisted execution state, idempotent task commits, scheduling, replay and restart recovery.

HLNA should reuse Jan's subagent/task UX and agent primitives where they fit, but must not assume they satisfy durable automation. The G8 workflow prototype should explicitly distinguish persisted task/session history from the actual ability to resume an interrupted execution after process restart.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/coworkPersistence.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/coworkMonitor.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/monitor.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/hooks/useCoworkSessions.ts

### 10.3 Workflow engine comparison — updated evidence

Cloacina 0.12.0:
- Embedded-first Rust workflow framework; Apache-2.0.
- Durable database-backed DAG workflows with retries, failure recovery, atomic task-completion commits and heartbeat-driven stale-claim recovery.
- SQLite and PostgreSQL; no external broker/queue/coordinator required for embedded mode.
- Also has event-driven in-process computation graphs, and a separate service mode with API/UI. HLNA should evaluate only the embedded library initially; do not add the service/control plane to a local desktop app without a concrete need.
- Content-versioned workflows are a useful feature to investigate, but compatibility and migration behaviour across changed workflow definitions must be tested.
- Strongest current fit for a durable DAG prototype, subject to tests and dependency/SQLite review.

Apalis 1.2.0:
- MIT-licensed core background-task library, with SQLite/PostgreSQL/Redis and other backends.
- Core advertises retries, rate limits, timeouts, idempotency, scheduling, priorities, result tracking, graceful shutdown and observability.
- The separately published apalis-sqlite backend documents durable jobs, retry/backoff, heartbeat/orphan recovery, delayed jobs and priority queues.
- apalis-workflow is now listed in the 1.2.0 crate ecosystem, so the earlier blanket characterization of its workflow support as only an unrelated early release is outdated. Its actual semantics and stability still need a dedicated test rather than assuming parity with the core queue.
- Stronger candidate for a general durable job queue; compare its workflow layer against Cloacina if HLNA needs both graph semantics and background workers.

Jan:
- Provides Cowork subagents, persisted session/todo/subagent state and bounded in-memory monitors, but not a demonstrated general durable workflow DAG engine.

Prototype only if the baseline exposes a real gap. Use the same test workflows for both candidates: process crash during a task, restart/recovery, duplicate delivery, idempotency, atomic completion, cancellation, pause/resume, retry/backoff, scheduled jobs, workflow-definition upgrade, SQLite contention/WAL, storage growth and idle CPU/RAM. Ensure all workflow actions call the HLNA broker at execution time; workflow definitions must not preserve stale authority grants.

References:
- https://docs.rs/cloacina/latest/cloacina/
- https://github.com/colliery-io/cloacina
- https://docs.rs/apalis/latest/apalis/
- https://docs.rs/apalis-sqlite/latest/apalis_sqlite/
- https://github.com/apalis-dev/apalis

### 10.4 Docling.rs — model footprint and licensing are first-class design constraints

The exact v2.86.14 workspace is MIT-licensed and requires Rust 1.92 for the PDF/ASR pipeline. It is split into focused crates for core document representation, format conversion, PDF/ONNX ML processing, CLI, language bindings and optional RAG/server layers.

Important deployment distinction:
- Declarative converters for formats such as DOCX, HTML, XLSX, PPTX and EPUB can operate without downloading the ML models and PDFium assets.
- Advanced PDF layout, OCR, table understanding, image understanding and ASR need separately downloaded model/runtime assets.
- The release's Linux x86-64 CLI archive is approximately 22.8 MB; this is not the complete installed footprint for ML-enabled use.
- The model notice enumerates multiple ONNX assets and their source revisions/licences. Examples include Apache-2.0 OCR and Whisper assets, Apache-2.0 layout model, CDLA-Permissive-2.0/Apache-2.0 TableFormer assets, and a separately licensed MIT figure-classifier model. PDFium has its own BSD-3-Clause and bundled dependency notices.
- The project supplies a digest-bound model manifest, model notices, individual licence texts and export records. This provenance/attribution approach is worth preserving in HLNA's model manager.
- Docling.rs also includes its own RAG/vector subsystem. Do not adopt that subsystem alongside Jan's vector DB by default.

Proposed HLNA integration:
1. Prototype the no-ML declarative converters first, measuring whether they outperform Jan's parser without model downloads.
2. Add PDF layout/OCR as an optional specialist capability, downloaded only after clear user consent.
3. Keep model/runtime assets in a separate, inspectable resource directory with pinned revision, SHA-256, source, licence and size metadata.
4. Benchmark the actual GPU/CPU memory footprint. Do not assume the ONNX path will fit alongside Ollama on a 4 GB GPU; test CPU execution and resource scheduling as well.
5. Normalize output into HLNA's own document representation and send it into one chosen retrieval/indexing pipeline.

References:
- https://github.com/docling-project/docling.rs/releases/tag/v2.86.14
- https://github.com/docling-project/docling.rs/blob/v2.86.14/Cargo.toml
- https://github.com/docling-project/docling.rs/blob/v2.86.14/docs/MODELS_NOTICE.md
- https://github.com/docling-project/docling.rs/blob/v2.86.14/docs/MODELS.md
- https://github.com/docling-project/docling.rs/blob/v2.86.14/CONTRIBUTING.md

### 10.5 sherpa-onnx — Rust binding build behaviour confirmed

The 2.0.3 Rust crate exposes safe Rust wrappers for offline and streaming ASR, TTS, VAD, speaker embeddings/diarization, punctuation, denoising and audio helpers. Its Rust example package defaults to static linking. The crate's build script can automatically download a matching native library archive when SHERPA_ONNX_LIB_DIR is not set.

HLNA must not allow that implicit download in a reproducible build. Pin the exact upstream release/commit and native archive checksum, prefetch it through a verified dependency step, and set the build to consume the verified local directory. Keep microphone capture optional and user-initiated. Model/voice licences remain separate from the Apache-2.0 engine licence.

References:
- https://docs.rs/sherpa-onnx/latest/sherpa_onnx/
- https://docs.rs/crate/sherpa-onnx/latest
- https://github.com/k2-fsa/sherpa-onnx/tree/v2.0.3/rust-api-examples

### 10.6 computer-use-linux — latest source and feature changes

The current repository main Cargo manifest reports 0.7.60, Rust 1.95, MIT. Its changelog records 0.7.59/0.7.60 changes on 20–22 November 2026, including additional background input routes for GNOME and KDE Wayland and fixes for KWin environments. The crate's capabilities and exact compositor behaviour continue to evolve quickly.

The GitHub Releases page surfaced v0.7.31 as the latest release tag, while current repository main, npm and crates.io metadata report newer 0.7.60 versions. This remains a provenance discrepancy; do not infer that the latest registry package corresponds to the visible GitHub release tag. Before pinning, retrieve the exact crates.io package, inspect its published checksum and source metadata, map it to a Git commit, and verify binary/source reproducibility. The manifest now also declares Rust 1.95 as its minimum, which must be checked against HLNA's chosen toolchain.

A newer capability set makes the broker boundary even more important: background actions can manipulate windows without moving the user's foreground pointer/focus on supported environments. This may improve UX but increases the need for precise window/process targeting, visible activity, scoped approval, cancellation and action auditing. Keep it disabled until the user enables desktop interaction. Prefer local stdio/supervised-process integration over its optional plain-HTTP MCP listener.

References:
- https://github.com/agent-sh/computer-use-linux/blob/main/Cargo.toml
- https://github.com/agent-sh/computer-use-linux/blob/main/CHANGELOG.md
- https://github.com/agent-sh/computer-use-linux/blob/main/SECURITY.md
- https://github.com/agent-sh/computer-use-linux/releases
- https://www.npmjs.com/package/@agent-sh/computer-use-linux

### 10.7 Updated disposition

| Component | Current disposition | Next gate |
|---|---|---|
| Jan extension runtime/catalog | Retain as baseline candidate; signed-index controls are a positive finding | Test signature/key lifecycle, worker isolation, revocation, resource exhaustion and host API |
| Jan Cowork task/subagent facilities | Reuse suitable UX and session primitives | Verify restart semantics; do not equate monitor persistence with durable workflow execution |
| Cloacina 0.12.0 | Strongest current durable-DAG prototype candidate | Crash/restart, idempotency, versioning, SQLite and resource tests |
| Apalis 1.2.0 + apalis-sqlite | Strong durable-job-queue comparison candidate | Verify workflow subcrate and SQLite backend semantics under the same test harness |
| docling.rs 2.86.14 | Split adoption: declarative parsers first, ML/PDF pipeline optional | Reproduce format quality and full model/runtime footprint |
| sherpa-onnx 2.0.3 | Voice prototype | Pin and verify native archive; model/voice licence and target-device tests |
| computer-use-linux 0.7.60 | Leading desktop-control prototype, not approved | Resolve package-to-commit provenance and test target compositor |

**No application source has been imported. HLNA v1 remains untouched.**


### 10.8 Voice alternatives — focused comparison

**whisper.cpp / whisper-rs**
- whisper.cpp is a mature C/C++ Whisper inference implementation with CPU support and optional NVIDIA, Vulkan, ROCm and other acceleration paths.
- whisper-rs 0.16.0 provides Rust bindings and is Unlicense; it is an ASR-specific comparison, not a complete ASR/VAD/TTS stack.
- Keep it in the voice benchmark as a focused transcription-quality/resource comparison against sherpa-onnx. Do not add it alongside sherpa-onnx in the shipped product unless tests demonstrate a material benefit.

**Piper**
- The current OHF-Voice piper1-gpl engine is GPL-3.0-or-later and its present development focus is Python; a C API is described as planned rather than an established stable Rust integration.
- Voice model rights are separate from the engine. Each voice has a MODEL_CARD, and its training lineage can carry restrictions from upstream/base voices. Some common historical voice families are derived from datasets that exclude commercial use; model names alone are not sufficient to establish rights.
- This is not a default HLNA TTS choice. Reconsider only if HLNA's final distribution licence is compatible, a specific voice's complete training chain is reviewed, and a stable integration path is demonstrated. Keep model cards and notices with any redistributed voice.
- sherpa-onnx remains the better unified prototype because it exposes Rust APIs for ASR, TTS and VAD, but its individual models/voices still require separate review.

References:
- https://github.com/ggml-org/whisper.cpp
- https://docs.rs/crate/whisper-rs/latest
- https://github.com/OHF-Voice/piper1-gpl
- https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/LICENSING.md
- https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/COMMERCIAL_USE.md
- https://github.com/k2-fsa/sherpa-onnx


## 11. Research update — 2026-11-24: Jan cross-surface permission audit

A deeper audit found materially different security defaults across Jan's desktop agent, headless CLI, MCP client and MCP server. HLNA must not assume that a desktop-safe configuration also makes CLI/API/automation use safe.

### 11.1 Headless CLI defaults are materially more permissive

At the pinned Jan commit:
- The CLI/TUI sets auto_approve = !safe. Approval prompts are therefore off by default; --safe enables prompts for writes, shell commands and MCP calls.
- Shell confinement is separate. The CLI sandbox defaults off unless enabled by --sandbox, project [tools].sandbox, or global configuration.
- Even when CLI shell confinement is enabled, CLI defaults allow network access and reading the user's home directory (for credential helpers), unless separately restricted.
- The project agent.toml default/allow/deny/allow_write policy is consumed by permissions_from, which is CLI-only. Desktop gating is implemented separately by the Tauri plugin.
- CLI default = read-only still advertises opaque MCP tools. It does not make third-party MCP tools read-only. The permissions module explicitly tests this behaviour; deny is needed to suppress MCP tools.
- auto_approve is inherited by dispatched subagents. HardDeny still takes precedence, but this is not an HLNA-wide security boundary.

This is an intentional coding-agent trade-off in Jan, not necessarily a Jan defect. For HLNA, every entry point must call the same broker, and the broker must decide at execution time based on the exact action, target, caller, current grant and user settings.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/jan-cli/src/main.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/agent/loop.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/agent/project.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/permissions.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/docs/src/pages/docs/agent/permissions.mdx
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/docs/src/pages/docs/agent/cli.mdx

### 11.2 Desktop MCP client has a meaningful one-use authorization boundary

Positive findings:
- A tool call is resolved to a specific server and connection generation. If a server is replaced after tool discovery, the stale call is refused rather than routed to the replacement.
- Before execution, call_tool consumes a one-use authorization bound to the exact thread ID, call ID, tool name, server name and origin. Missing, mismatched, replayed or already-consumed authorizations are refused.
- Calls have a configurable timeout, cancellation support and output truncation before results enter conversation history.
- Saved grants are distinct from one-shot and thread grants. Only explicit "Allow always" is persisted; thread grants are in memory and dropped on restart. Saved grants can be revoked.
- The global allow_all_mcp setting is a persisted, explicit opt-in. It does not cover extension tools or strict calls; strict calls always ask and do not save the answer.
- Server-wide grants do not apply to extension-origin tools.

This is a good consent-store baseline. HLNA should retain call-bound one-use authorization, but add broker-enforced resource scopes, grant expiry, caller identity, action class (observe/mutate), audit and revocation generation. Re-check policy immediately before side effects.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/mcp/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/consent.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/commands.rs

### 11.3 Jan's outbound MCP server is safer by default than its general CLI

The separate jan mcp serve surface:
- Defaults to read/search/memory/skill/web tools; filesystem writes and shell execution are not offered unless --allow-write and --allow-exec are explicitly set.
- Uses the same tool schemas, dispatcher and gate as Jan's agent, but there is no human available to answer a prompt. Operations requiring approval are refused unless the explicit served-tool opt-in made them eligible.
- Confines writes to the one project root fixed at server startup; escaping reads/writes are refused.
- Defaults to OS sandboxing on and network access off for its shell. Project agent.toml may override these settings, so HLNA must inspect effective configuration.
- Hides Jan's own home from served tools even if shell sandboxing is disabled.
- HTTP binds only to 127.0.0.1, requires a 256-bit random bearer token, and compares the credential in constant time.

This is a better starting point for tool reuse than launching a general CLI agent with default auto-approval. HLNA should supervise it as an untrusted tool provider, restrict the exposed tool list, prefer stdio, and broker every resulting action. Do not enable write/exec until separately granted.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/cli/mcp_serve.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/mcp/server/mod.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/mcp/server/http.rs

### 11.4 Updated security disposition

- Reuse Jan's desktop one-use consent-store pattern as a baseline, not its entire policy model.
- Do not launch Jan's general CLI agent as an HLNA child process with default flags. If a CLI process is ever used, explicitly configure safe mode, sandbox, network/home access, allowed tools and project scope; still enforce the HLNA broker outside the child.
- Prefer the narrower jan mcp serve integration for exposing Jan tools to another agent, and keep it stdio-only unless a concrete need justifies loopback HTTP.
- Ensure MCP, extension, workflow, subagent, desktop-control and CLI paths all converge on one Rust-side broker. No frontend prompt or MCP server grant may bypass it.


## 12. Research update — 2026-11-24: document-processing alternatives and deployment audit

The document-processing shortlist now includes a newer Apache-2.0 Rust candidate, a specialist PDF extractor, and a higher-scoring but copyleft Python candidate. These are benchmark candidates, not approvals.

### 12.1 docling.rs current release and build/runtime controls

The current source release is now v2.88.1 (commit 8b819fad84ccd069fe4b1ad2adbbc9bd5794c4fc, 2026-11-24), superseding the previously recorded v2.86.14 baseline. It remains an MIT Rust workspace, with the PDF crate carrying an additional BSD-3-Clause notice for Adobe mapping resources.

Positive findings:
- The default PDF pipeline is moving toward a pure-Rust renderer; the optional PDFium feature is not required for the normal path.
- Declarative Office/HTML/EPUB conversion can be separated from ML-heavy PDF layout/OCR/table features.
- Model assets have a digest-bound manifest, per-artifact upstream revision and SPDX licence, model notices/licence files, and immutable content-addressed snapshots. The rolling models-v1 release alone is not a durable pin; save its SHA256SUMS or use the immutable models-v1-<digest> snapshot.
- ONNX execution-provider features are explicit. CPU is the default; CUDA/TensorRT/DirectML/CoreML require explicit build features.
- The optional load-dynamic feature searches ORT_DYLIB_PATH, the models directory and then the system library path. Because this loads native code into the process, HLNA should avoid that feature initially or replace it with a single verified canonical runtime path.

Build caveat:
- The docling-onnx crate enables ort's download-binaries feature. A normal ML-enabled build therefore obtains a prebuilt ONNX Runtime artifact through the dependency's build mechanism. HLNA must pin the crate lockfile and verify/cache that native binary independently; a source-only Cargo.lock does not by itself establish the provenance of every downloaded native artifact.
- Model snapshots and their hashes are strong positives, but do not eliminate the need to pin the native ONNX Runtime archive, toolchain and build inputs.

Current disposition: retain docling.rs as a serious document-processing candidate. Prototype no-ML declarative converters first; benchmark PDF text-only separately; add model-backed PDF layout/OCR/table features only if they outperform alternatives and fit the target resource budget.

Pinned references:
- https://github.com/docling-project/docling.rs/tree/v2.88.1
- https://github.com/docling-project/docling.rs/blob/v2.88.1/crates/docling-onnx/Cargo.toml
- https://github.com/docling-project/docling.rs/blob/v2.88.1/crates/docling-pdf/Cargo.toml
- https://github.com/docling-project/docling.rs/blob/v2.88.1/docs/MODELS.md
- https://github.com/docling-project/docling.rs/blob/v2.88.1/docs/MODELS_NOTICE.md
- https://github.com/docling-project/docling.rs/blob/v2.88.1/scripts/install/models_catalog.json

### 12.2 docparse-rs — new Apache-2.0 multi-format Rust candidate

Repository: https://github.com/yzlabai/docparse-rs

The inspected main-branch source is a Rust workspace currently declaring version 0.1.0 and Apache-2.0. It advertises 12 formats (PDF, DOCX, HTML, XLSX, PPTX, Markdown, CSV, SRT/VTT, LaTeX, EML, PNG/JPEG, AsciiDoc), one CLI/library, MCP and REST interfaces, a unified positioned document IR, outline/chunk outputs with page+bbox citations, and optional OCR/layout/table/formula enhancements. Its README reports 142 tests and its status notes extensive fuzzing; these are upstream claims to verify.

Potential advantages:
- Pure-Rust default parser path with no model requirement; optional PP-OCRv6 model files are about 7 MB.
- Strongly agent-oriented IR: page, bounding box, section hierarchy, confidence and element-level source provenance.
- Deterministic output and a quality/profile report to identify pages that need optional enhancement.
- Explicit resource guards: 50,000-page ceiling and ZIP container limits of 2 GiB declared uncompressed content and 250:1 compression ratio.
- Model-backed stages are opt-in; the CLI forces batch jobs to one when ML models are active to bound memory.

Important risks/gaps:
- It is very new (workspace version 0.1.0) and has a substantially smaller adoption/maintenance history than Docling. Its impressive self-reported benchmark numbers are not independent verification.
- The PP-OCRv6 downloader uses Hugging Face URLs pointing at the floating main branch. It checks only that a download is larger than 1 KiB; the inspected code does not verify a pinned revision or cryptographic digest. HLNA must not use that downloader unchanged. Pin model revisions and hashes, enforce size limits, and cache verified assets.
- Its MCP tools accept a caller-supplied local path and pass it directly to the parser; the inspected path has no project-root authorization. Running this MCP server would therefore expose whatever local files the process can read to the connected agent. Do not expose the upstream MCP server directly in HLNA.
- Its REST service binds to 127.0.0.1 by default and has no authentication. It allows an explicit wider host bind; the upload limit is 256 MiB. Do not expose it to a network. Prefer an in-process library integration after HLNA broker path authorization, or a tightly sandboxed supervised process.
- Optional VLM enhancement can call an OpenAI-compatible service; keep that disabled unless the user explicitly configures it.

Current disposition: add docparse-rs to the document benchmark as a promising lightweight multi-format contender, but not as a production dependency yet. First pin a source commit, inspect its full dependency/licence graph and tests, review the PDF/Office parsers for malformed input, and reproduce extraction quality and resource measurements. If adopted, call its library only behind the HLNA broker; replace model fetch logic with verified, pinned assets.

Pinned inspected files:
- https://github.com/yzlabai/docparse-rs/blob/main/Cargo.toml
- https://github.com/yzlabai/docparse-rs/blob/main/crates/docparse-cli/src/mcp.rs
- https://github.com/yzlabai/docparse-rs/blob/main/crates/docparse-cli/src/server.rs
- https://github.com/yzlabai/docparse-rs/blob/main/crates/docparse-core/src/limits.rs
- https://github.com/yzlabai/docparse-rs/blob/main/crates/docparse-ocr/src/fetch.rs
- https://github.com/yzlabai/docparse-rs/blob/main/crates/docparse-pdf/src/lib.rs

### 12.3 Firecrawl pdf-inspector — specialist PDF fast path

Repository: https://github.com/mbrukman/firecrawl-pdf-inspector

The inspected crate is MIT-licensed, Rust, version 0.1.7, built around lopdf. It classifies PDFs as text-based, scanned, image-based or mixed; extracts positioned text; reconstructs reading order and tables; and converts native-text PDFs to Markdown without OCR or external services. It includes Python, Node and browser-WASM bindings.

Its published 200-PDF benchmark reports strong native-text reading-order/table scores and sub-second aggregate processing on an Apple M4 Pro. The benchmark has reproducible result artifacts, but must still be reproduced on HLNA's target machine and document corpus. It is PDF-only, not a multi-format replacement, and its current version is early.

Current disposition: include it as a specialist native-text PDF benchmark and possible fast-path parser. It could complement Docling/docparse-rs by cheaply routing born-digital PDFs away from expensive OCR/layout pipelines. Do not ship a second PDF parser unless the accuracy/latency benefit is measurable.

References:
- https://github.com/mbrukman/firecrawl-pdf-inspector
- https://github.com/mbrukman/firecrawl-pdf-inspector/blob/main/Cargo.toml
- https://github.com/mbrukman/firecrawl-pdf-inspector/blob/main/LICENSE
- https://github.com/firecrawl/opendataloader-bench/tree/abi/pdf-parser-benchmark-results

### 12.4 DocSlicer — benchmark leader, licensing caveat

Repository: https://github.com/DocSlicer/DocSlicer

The current repository describes a Python document parser/chunker for PDF, DOCX, PPTX and HTML, with hierarchy-aware chunks and structured tables. Its associated BizDocBench leaderboard reports DocSlicer 0.88 versus Docling 0.70 on 77 business documents. However:
- DocSlicer and BizDocBench are maintained by the same publisher, so the result is vendor-reported rather than independent.
- The benchmark says scanned documents, handwriting and OCR are out of scope.
- It is a narrow 77-document corpus and the scoring weights and document selection need independent review.
- The current source is dual-licensed AGPL-3.0-only or commercial. A proprietary/closed-source distribution would need a licence review and likely a separate commercial agreement; do not copy it into HLNA by default.
- It requires Python 3.10+, with optional Playwright/Chromium for browser-rendered HTML and Tesseract/OpenCV for OCR.

Current disposition: use its benchmark corpus/methodology as an additional evaluation reference and inspect its strengths in business-document hierarchy/table extraction. Do not adopt its code unless HLNA's distribution licence is compatible or a commercial licence is deliberately acquired.

References:
- https://github.com/DocSlicer/DocSlicer
- https://github.com/DocSlicer/DocSlicer/blob/main/LICENSE
- https://github.com/DocSlicer/DocSlicer/blob/main/LICENSE-COMMERCIAL.md
- https://github.com/DocSlicer/BizDocBench

### 12.5 Revised document-processing benchmark plan

Compare at least:
1. Jan's existing parser/RAG baseline.
2. docling.rs v2.88.1 no-ML declarative formats.
3. docling.rs PDF text-layer-only.
4. docling.rs ML PDF path with optional models.
5. docparse-rs deterministic default path.
6. docparse-rs optional OCR/layout/table path only where needed.
7. pdf-inspector as a native-text PDF fast path.
8. DocSlicer as a benchmark reference only unless licensing is resolved.

Use one locally held, licence-cleared corpus with human-checked ground truth: born-digital PDFs, scanned PDFs, mixed PDFs, complex tables, multi-column layouts, CJK/RTL/Unicode, DOCX, PPTX (including notes/charts), XLSX, HTML, malformed/hostile files and very large documents. Record exact parser/model commits and hashes. Measure text accuracy, reading order, heading hierarchy, table cells, page+bbox provenance, hidden-text handling, extraction coverage, throughput, cold-start, peak RSS, CPU, GPU memory, model disk footprint, and concurrent Ollama performance. Score each format separately; do not allow a fast DOCX parser to mask poor scanned-PDF handling.

**Updated disposition:** docling.rs remains the mature broad-feature candidate; docparse-rs is now a promising lighter Rust candidate requiring maturity/security work; pdf-inspector is a specialist PDF fast path; DocSlicer is benchmark/reference-only pending licence compatibility. No parser has been selected for production.


## 13. Research correction and update — 2026-11-24: Jan desktop tool gate, MCP routes and local API server

A re-check of the exact pinned implementation found that an earlier security note incorrectly described the desktop agent's ToolPermissions default as ReadOnly. A subsequent source-level re-check also corrected the interpretation of what the Allow default does. This section supersedes earlier statements.

### 13.1 Correct interpretation: desktop ToolPermissions default is Allow, but not an allow-all gate bypass

At Jan commit 49a84bdeaebdfc0f36c00f252eb638f516a48432:
- `ToolPermissions::default()` returns `Self::allow_all()`, which sets `PermissionDefault::Allow`.
- However, `ToolPermissions::is_allowed(name)` checks only explicit `allow` and `allow_write` pattern lists. It does not consult the default enum.
- The desktop `execute_tool_inner` passes `ToolPermissions::default()` and empty `SessionGrants` to `resolve_decision`.
- The shared gate first applies deny rules, hidden-path checks and shell-escalation checks; then it checks explicit allow patterns; otherwise it reaches capability-specific handling. The Allow default does **not** short-circuit those capability branches.
- Therefore the previous statement that the desktop Allow default bypasses capability prompts was incorrect. The correct statement is: desktop passes an Allow-valued default, but for built-in tool execution the gate's early allow check is based on explicit allow patterns, not that default. The default's separate significance includes MCP tool advertisement behavior.
- Desktop then handles decisions in its caller: writes within the ephemeral thread workspace are permitted because the workspace is disposable and shell is confined; writes outside approved roots are refused; shell execution is permitted only when an enforcing jail is available; escalation is refused. Read-only attached folders and explicitly writable attachments have separate scope rules.
- This does not remove the need for end-to-end tests. The handler comments explicitly state that the gate runs before handlers; path checks, symlink handling, attachment validation, process sandboxing and IPC command reachability are separate controls.

Tests must cover writes outside the ephemeral workspace, attached-folder read/write scope, symlink/path races, hidden Jan-home access, shell behavior when no enforcing jail is available, and escalation. Do not describe the desktop policy as ReadOnly, but also do not claim its Allow enum makes all built-ins automatically permitted.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/permissions.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/gate.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/sandbox.rs

### 13.2 Distinct MCP execution surfaces

The pinned source confirms that Jan has several materially different MCP paths:
- Desktop agent MCP calls use a dedicated consent flow with one-use authorization bound to the thread/call/tool/server/origin, server-generation checks, timeouts, cancellation and output caps.
- Jan's MCP server mode reuses built-in schemas, handlers and the shared gate. It defaults to read/search/memory/skill/web tools; filesystem writes and shell are opt-in; paths are confined to a fixed served project root; shell is sandboxed; hidden Jan home is refused.
- The Local API Server's `/orchestrations` endpoint collects MCP tools and invokes the shared `execute_mcp_tool_calls` routine directly. That routine resolves a server route/generation and invokes `service.call_tool` with timeout and output truncation, but does not call the desktop one-use consent flow or a per-call user prompt. The route is guarded by the explicit `enable_server_tool_execution` setting. This is a distinct headless authorization boundary, not a desktop consent equivalent.
- MCP stdio/HTTP/SSE server activation and process lifecycle are separate from per-call tool authorization. Treat configured remote or local MCP servers as untrusted code/services.

HLNA requirement: all these entry points must converge on the same broker at the side-effect boundary. A setting that enables headless tool execution must not grant blanket permissions to all tools or bypass per-resource authorization.

### 13.3 Local API server: authentication and headless tool execution

Jan's Local API Server documentation and pinned implementation establish:
- The normal local API server host is 127.0.0.1. An empty API key disables authentication only on the default loopback host; Jan refuses a non-loopback bind without a configured key.
- When configured, requests authenticate with a Bearer token or X-Api-Key. Host-header and Origin checks add browser-origin protections; requests without an Origin are intentionally allowed for SDK/CLI clients, so Origin checks are not a substitute for authentication.
- The server-side `/orchestrations` route can ask a model for tool calls and execute configured MCP tools without per-call approval. It is available only when the user explicitly enables the Local API Server's server-side tool execution setting.
- Jan's in-process llama.cpp engine worker binds to 127.0.0.1 and checks a Bearer API key on every request. It is a distinct service from the Local API Server proxy.

HLNA disposition:
- Keep any local API server disabled by default. If needed, bind loopback only, require a high-entropy secret even on loopback, validate Origin/Host as defense in depth, and expose only explicitly selected endpoints.
- Do not expose headless orchestration until every MCP call is broker-authorized at execution time, with scoped grants and audit.
- Prefer a private in-process Rust service or supervised stdio MCP for internal integrations. Do not expose a broad unauthenticated localhost API to browsers or other local processes.
- Separate inference transport credentials from agent/tool execution credentials.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/server/proxy.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-llamacpp/src/engine/http.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/docs/src/pages/docs/desktop/api-server.mdx

### 13.4 Security-gate implications

Add tests for:
1. `ToolPermissions::default()` and `is_allowed()` semantics separately; ensure the default enum is not mistaken for an explicit allow-list match.
2. Desktop `execute_tool_inner` decisions and every handler's filesystem/path/sandbox checks, including symlink swaps and TOCTOU.
3. A desktop tool call cannot write outside approved roots.
4. Shell execution refuses if an enforcing OS sandbox is unavailable; no escalation path is silently granted.
5. Local API server with empty key cannot bind off-loopback; configured key is required and validated.
6. `/orchestrations` remains disabled by default and every individual MCP call is broker-gated when enabled.
7. Origin-less SDK/CLI requests still require credentials whenever the service is reachable outside a strictly private in-process boundary.
8. Desktop consent, MCP server, CLI, extension and API orchestration routes all enforce the same resource/action policy at the moment of side effect.

## 14. New reusable security and workflow candidates — 2026-11-24

### 14.1 Cedar policy engine

- Repository: https://github.com/cedar-policy/cedar
- Apache-2.0 Rust implementation; dedicated policy language and evaluator, schema validator, CLI, symbolic compiler and automated-reasoning tooling.
- Supports fine-grained authorization models including RBAC and ABAC; policy is separate from application code, default-deny semantics with explicit forbid precedence.
- Strong candidate to prototype as HLNA's *policy evaluation layer*, not as the permission broker or enforcement boundary itself.
- The broker must still authenticate the caller, construct trusted principal/action/resource/context attributes, call Cedar, and enforce the result immediately before a side effect. Never let an LLM provide trusted principal identity, resource ownership or approval state.
- Evaluate whether Cedar adds useful policy expressiveness without making the app difficult to maintain. Compare with a small typed Rust policy engine and property-based tests. Do not assume Cedar replaces OS sandboxing.

### 14.2 OS sandbox building blocks

- Rust Landlock: https://github.com/landlock-lsm/rust-landlock — MIT/Apache-2.0; safe Rust abstraction for Linux Landlock, unprivileged filesystem restrictions from Linux 5.13, with later ABI extensions for network and IPC controls.
- cap-std: https://github.com/bytecodealliance/cap-std — capability-oriented filesystem APIs; useful to reduce ambient filesystem authority in Rust code. It is not a process sandbox and does not replace kernel enforcement.
- Cedar, cap-std and Landlock solve different layers: policy decision, in-process capability-safe APIs, and process-level kernel restrictions respectively.
- Jan already has platform-specific jail machinery (bubblewrap/Linux, Seatbelt/macOS and AppContainer/Windows). Audit and benchmark it before replacing it. Any missing or non-enforcing backend must fail closed for operations that require confinement.
- Newer standalone sandbox crates/projects surfaced (Sandlock, evalbox-sandbox, systemg, zandbox). Treat as research-only until source, maintenance, kernel compatibility, threat model, license and adversarial tests are independently reviewed. Do not add a young sandbox dependency merely because its feature list is broad.

### 14.3 Workflow engine expansion

Candidates beyond the previously shortlisted Apalis and Cloacina:
- Acts 0.25.0: https://docs.rs/acts/latest/acts/ — YAML-defined workflows, embedded Rust engine or server, durable transactional state transitions, branches, joins, subflows, timers, human/message actions, pluggable storage. Promising for a user-authored declarative workflow model; inspect project maintenance, license, package execution model, SQLite backend and security before adoption.
- Durare 0.5.0: https://github.com/SamuelXing/durare — DBOS-compatible Rust durable execution, SQLite/Postgres state providers, checkpoint/recovery semantics, Apache-2.0/MIT. Smaller community than established orchestration products; promising for code-first durable workflows but not a visual workflow designer.
- Cloacina 0.12.0 remains a strong embedded DAG candidate with SQLite/Postgres, task retries/recovery and content-versioned workflows.
- Apalis 1.2.0 remains a general durable background queue with retries, idempotency, scheduling and SQLite/Postgres backends; its workflow add-on is still a separate release candidate and should not be treated as equally mature.
- Prototype at most one workflow engine plus a lightweight job queue only if necessary. Test crash windows around external side effects, idempotency keys, retries, cancellation, pause/resume, version migration, concurrency and SQLite contention. Durable execution cannot guarantee exactly-once effects in external systems without idempotent operations or transactional integration.

### 14.4 Voice integration refinement

- sherpa-onnx 2.0.3 remains the leading unified offline ASR/TTS/VAD candidate. Its Rust crate exposes offline/streaming recognition, TTS, VAD, diarization, punctuation and denoising.
- Build-provenance caveat remains: the Rust crate statically links by default and may download a matching prebuilt native archive during build when `SHERPA_ONNX_LIB_DIR` is unset. HLNA must pin release, archive checksum, build feature set and cache; do not allow an invisible floating build-time download.
- speechkit 0.5.0: https://docs.rs/speechkit/latest/speechkit/ is a Rust convenience facade over sherpa-onnx plus optional cloud providers and audio devices. It may reduce integration work, but does not replace the underlying runtime or remove model/native-library provenance work. Inspect feature defaults carefully and disable cloud providers for the local-first build.
- whisper-rs 0.16.0 remains a focused ASR comparison, Unlicense, with optional CUDA/Vulkan/OpenBLAS/Metal feature paths. It is not a unified TTS/VAD stack.
- Evaluate ASR/TTS model size, language quality (especially user's target languages), latency, RAM/VRAM, cold start, CPU fallback and concurrent Ollama performance on the actual target PC. Keep voice models optional downloads with independent licence and checksum records.


### 14.5 Jan jail backend caveat and extension-network review

The exact pinned Jan jail source documents three platform backends:
- Linux bubblewrap, macOS Seatbelt via the absolute `/usr/bin/sandbox-exec` path, Windows AppContainer.
- Intended common policy: writes only to thread workspace/private temp; network denied unless explicitly allowed; desktop masks the Jan data folder and hides the Jan home; shell is withheld if no enforcing backend exists.
- AppContainer has a stricter default read surface (system paths granted to ALL APPLICATION PACKAGES) but has no read-only workspace policy. Jan refuses a read-only workspace under that backend rather than making it writable.
- **Windows-specific caveat:** Jan's jail source explicitly says AppContainer does not enforce the `hide_root` subpath mask; only the command-token scan remains for hiding Jan home there. This differs from Linux bubblewrap and macOS Seatbelt. It must be tested and may require a stronger Windows-specific policy or a narrower set of exposed paths.
- Linux detection relies on locating bubblewrap; the policy implementation must be tested with the actual installed binary/version, kernel and desktop session. Never assume backend availability based only on OS name.
- The command token scan is best-effort and is not a replacement for the OS sandbox. Keep escalation unavailable in HLNA unless a separately designed, user-confirmed privileged workflow exists.

Pinned source:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/jail.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/appcontainer.rs

Extension runtime review:
- Jan's extension install pipeline stages bundles, validates manifest/host API version, caps compressed package size, verifies indexed tarball integrity, and records whether the index signature was verified. Updates compute permission diffs; entry source is hash-checked when read; safe mode can disable all extensions.
- HTTP requests are mediated through a Rust client without cookie storage and automatic redirects disabled; request methods, headers and body size are constrained, response size/stream/timeouts and concurrent requests are capped, and the local API server port is blocked.
- Host methods use an exhaustive permission-policy table and validate arguments before checking grants. Built-in extensions have their manifest-requested permissions; installed extensions use user grants.
- Accepted caveats in the source: DNS resolution is not pinned/validated against the granted hostname; system/environment proxy configuration can route requests through the user's proxy. Host grants are hostname-level, so HLNA should consider DNS rebinding/private-address protections and redirects as explicit threat-model items.
- The JavaScript Worker is not an OS process sandbox. Do not treat worker separation or WebAssembly availability as CPU/memory/OS isolation.
- Reuse the installer/grant-diff model only after independent review of key rotation, source trust, signature verification, rollback, safe-mode recovery, package extraction, dispatcher exhaustiveness and revocation races. All extension host calls must still be routed through HLNA's central broker; do not give extensions direct Tauri IPC access.


### 14.6 DBOS Rust SDK comparison

- Official DBOS Rust SDK: https://github.com/dbos-inc/dbos-transact-rust
- The published Rust `dbos` crate is currently 0.6.0 and explicitly marked pre-production / not production-supported; its documented backend is PostgreSQL.
- Durare 0.5.0 is a community DBOS-compatible SDK with SQLite and PostgreSQL providers, but is not the official DBOS Rust SDK. It is Apache-2.0/MIT and currently has a smaller community.
- For HLNA's embedded desktop/local-first SQLite design, official DBOS Rust is currently a reference candidate rather than a direct fit. Durare is worth a prototype alongside Cloacina/Acts, with special scrutiny of external side-effect semantics and crash recovery.
- Do not equate replay/checkpoint guarantees with exactly-once external effects. Use idempotency keys, transactional outbox/inbox patterns where possible, and reconciliation for operations that cross database/process/network boundaries.
