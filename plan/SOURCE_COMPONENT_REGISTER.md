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


## 9. Research update — 2026-11-24

This section adds independent source research performed after the preliminary audit. Findings are tied to official repositories, release notes or project documentation where possible. Performance claims made by upstream projects remain unverified until reproduced on the HLNA target machine.

### 9.1 computer-use-linux — leading Linux desktop interaction candidate

- Repository: https://github.com/agent-sh/computer-use-linux
- Crate: https://crates.io/crates/computer-use-linux
- Latest crate version observed: `0.7.59`, published 2026-11-20.
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
- The crates.io version observed (0.7.59) is newer than the latest GitHub release tag surfaced during the search (v0.7.31). Resolve this release/tag discrepancy and pin a verifiable source commit before adoption.

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

Jan already contains an extension architecture and Wasmtime-related runtime code. Extism should remain deferred unless a pinned, reproducible comparison shows it provides a material benefit. If ever prototyped, disable default features and expose only narrowly defined HLNA host functions; no plugin gets ambient filesystem or network access.

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

The GitHub Releases page currently identifies signed release tag v0.7.31 (commit cc38489) as its latest tagged release, while docs.rs currently presents crates.io package computer-use-linux 0.7.59. These are not interchangeable version identifiers. Before adoption, establish the exact crates.io source provenance, corresponding Git commit/tag, release assets, signatures/checksums and dependency graph. Do not pin a floating latest package or infer that the crates.io package is identical to the latest GitHub release.

The project remains a strong Linux desktop-control prototype, but all observation and mutation must be mediated by HLNA's broker. Its on-screen activity indicator is a useful UX/security feature to evaluate. Test the target compositor, portal consent, focus validation, accessibility data exposure, stale-target handling, input correctness and stop/revoke behavior. Never expose its full MCP toolset directly to the model.

References:
- https://github.com/agent-sh/computer-use-linux/releases
- https://github.com/agent-sh/computer-use-linux/security
- https://docs.rs/crate/computer-use-linux/latest
