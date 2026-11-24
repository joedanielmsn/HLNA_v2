# HLNA v2 — Source Adoption Matrix

This is the working module-level audit. A project being listed here does not mean its code is approved for integration. All revisions are pinned for reproducible review, not assumed to be the latest release.

## Current decision key

- **Foundation candidate:** likely to form the base application.
- **Adopt selectively:** candidate source modules only, after dependency and security review.
- **Evaluate:** compare against alternatives and benchmark before deciding.
- **Hold:** known blocker or insufficient evidence.

## 1. Jan — desktop application foundation

Repository: https://github.com/janhq/jan  
Evaluation revision: `49a84bdeaebdfc0f36c00f252eb638f516a48432`  
Root licence: Apache-2.0 (preserve notices; separately audit all assets and dependencies).

| Source area | Intended use | Decision / work |
|---|---|---|
| `web-app/` | React desktop UI, conversation experience, settings and navigation | Foundation candidate; rebrand and remove irrelevant Jan-specific features |
| `web-app/src/constants/providers.ts` | Provider definitions and configuration fields | Reuse/adapt provider metadata; local Ollama endpoint is user-configured |
| `web-app/src/lib/custom-chat-transport.ts` | Streaming chat transport and message/tool conversion | Inspect and selectively refactor; currently imports llama.cpp APIs and Jan-specific service/tool state, so do not copy wholesale |
| `docs/src/pages/docs/desktop/remote-models/custom-endpoint.mdx` | Documents OpenAI-compatible custom endpoints and Ollama base URL | Confirms Jan custom endpoint path; implementation still needs runtime test |
| `src-tauri/plugins/tauri-plugin-agent-tools/` | Agent tool core, permissions/grants, sandbox and host integration | Strong source candidate; audit each tool and narrow grants |
| `src-tauri/plugins/tauri-plugin-rag/` | Document parsing and RAG utilities | Candidate; inspect supported formats and transitive dependency weight |
| `src-tauri/plugins/tauri-plugin-vector-db/` | SQLite vector persistence/search | Candidate; inspect schema, extension loading and migration story |
| `packages/extension-api/` | Extension API contract | Candidate; retain only after permission model is aligned |
| `packages/extension-runtime/` | Extension runtime | Candidate; compare to Extism before selecting one runtime |

### Jan-specific implementation risks

- The custom chat transport is not provider-neutral in isolation: the inspected file imports llama.cpp APIs, extension host functions and Jan service hooks. Reuse the design and extract provider-independent pieces rather than transplanting the file unchanged.
- The agent-tools crate has a Tauri-free core behind features; inspect whether HLNA can reuse the core without inheriting unneeded GUI/runtime dependencies.
- The RAG plugin pulls document libraries such as PDF extraction, ZIP, XML, CSV, spreadsheet and HTML parsing. Audit each parser and dependency.
- The vector DB crate uses rusqlite with bundled SQLite and load-extension support. Review whether loadable extensions are needed and disable unnecessary capability.
- Jan's app build has native-engine worker/resource assumptions. The no-llama.cpp/Ollama-first build path is not proven until built.
- Replace Jan identifiers, data roots, migration paths, telemetry and updater endpoints. Preserve Apache notices and audit font/icon/model assets individually.

## 2. computer-use — desktop interaction library

Repository: https://github.com/lindoelio/computer-use  
Inspection revision: `780bb89e9bb7cfc8a43f999a273b312c832a9a3b`  
Package licence: MIT OR Apache-2.0. Package declares Rust 1.91.

| Exact source area | Intended use | Status |
|---|---|---|
| `src/protocol.rs` | Typed Action/Request/Response and dispatch interface | Inspect for possible library-level reuse |
| `src/backend/mod.rs` | Backend trait and dispatch abstraction | Strong candidate |
| `src/backend/linux/mod.rs` | Linux implementation entry point | Strong candidate; assess desktop session compatibility |
| `src/backend/linux/atspi.rs` | Linux accessibility integration | Candidate; review AT-SPI permissions, secure fields and process boundaries |
| `src/backend/linux/portal.rs` | Wayland XDG portal capture/input | Candidate; user-mediated portal flow is valuable |
| `src/backend/linux/x11.rs` | X11 input implementation | Candidate; scope and safety review required |
| `src/tree.rs`, `src/element.rs` | Accessibility tree and element actions | Candidate; revalidate target before action |
| `src/policy.rs` | Action policy | Reference/possible selective reuse; HLNA central broker remains authoritative |
| `src/audit.rs` | JSONL audit events | Candidate; integrate with HLNA audit schema |
| `src/browser/` | CDP browser control | Optional feature; review navigation and secret-field policies |
| `src/isolation/` | Isolation utilities | Inspect before relying on it as a security boundary |

**Important compatibility blocker:** Jan's pinned workspace uses Rust 1.88 (from the prior baseline audit), while computer-use declares Rust 1.91. Direct workspace integration may require upgrading the toolchain and revalidating Jan, or adapting/isolating the crate. Do not silently downgrade the dependency or claim compatibility. The crate's Wayland portal feature pulls PipeWire/libclang system dependencies; default features are off, while upstream release binaries enable selected features. Decide which features HLNA actually needs.

Security note: computer-use supports real desktop actions. Do not expose unrestricted click/type/keyboard/browser capabilities. All actions need explicit scopes, approval policy, secret-field protections, cancellation and audit.

## 3. sherpa-onnx — voice

Repository: https://github.com/k2-fsa/sherpa-onnx  
Inspected Rust API example revision: `4cf93196dc28bac7784967b2d70a041327ee133d`  
Root licence: Apache-2.0. Models/assets need separate review.

| Source area | Intended use | Status |
|---|---|---|
| `rust-api-examples/` | Rust integration examples | Reference and prototype starting point |
| `rust-api-examples/for-advanced-users.md` | Native library linking/build behaviour | Key packaging reference |
| Rust crate and sys build scripts | ASR/VAD/TTS bindings and native library linkage | Evaluate with a minimal test application before adoption |

**Packaging concern:** the documented default Rust crate setup statically links and automatically downloads a matching native library archive. This can increase build time and binary/package size. Test the shared-library feature and packaging implications before selecting it. Benchmark a small streaming ASR model, VAD and TTS independently. Do not assume all three are needed in the first release.

## 4. Apalis — task/workflow engine

Repository: https://github.com/apalis-dev/apalis  
Inspection revision: `81dd4e2d4a882e20a404e78749e40f2a663fadf3`  
Root licence: MIT; `apalis-workflow` crate manifest declares MIT.

| Source area | Intended use | Status |
|---|---|---|
| `apalis-workflow/` | Sequential and DAG workflow graph execution | Evaluate; promising fit |
| `apalis-workflow/Cargo.toml` | Dependency and feature footprint | Inspect before adoption |
| `apalis-sqlite` (crate documented by upstream) | SQLite persistence backend | Confirm exact workspace path/API and test crash recovery |

Upstream workflow README describes sequential and DAG workflows, parallel/concurrent steps, resumable/durable execution, and SQLite storage support. It also shows tracing enabled by default. For HLNA, disable exporters and keep observability local. Confirm whether Apalis provides the lifecycle/cancellation semantics we need; HLNA still owns user approvals and permission checks.

## 5. Extism — alternative plugin runtime

Repository: https://github.com/extism/extism  
Root licence inspected: BSD-3-Clause.

Compare with Jan's existing extension API/runtime and Wasmtime architecture. Do not add Extism merely because it is another good runtime. Select one primary extension system unless multi-runtime support is demonstrably necessary. Audit host functions, WASI access, filesystem/network grants, memory/fuel limits and extension provenance.

## 6. Docling — document intelligence

Repository: https://github.com/docling-project/docling  
Root licence inspected: MIT.

Candidate for an optional on-demand document worker, not a default always-running service. Audit Python dependencies, OCR backends, model weights and external downloads. Measure cold start, peak RAM/CPU, disk footprint and extraction quality against Jan's Rust RAG parser on representative PDFs, tables and office documents.

## 7. sqlite-vec — vector search alternative

Repository: https://github.com/asg017/sqlite-vec

**Hold.** Current licence and release/maintenance status were not verified in this pass. Do not copy or ship until that evidence is recorded. Benchmark only against Jan's current vector DB implementation and at least one maintained alternative.

## 8. Immediate comparison tasks

1. Build Jan unchanged at the pinned revision; capture baseline build/runtime metrics.
2. Prototype Ollama custom-provider setup with the exact local model; verify streaming, cancellation, model IDs and context behaviour.
3. Inspect Jan provider transport and identify the minimum reusable provider-independent module boundary.
4. Resolve the Rust 1.88 vs 1.91 computer-use toolchain issue before deciding whether to vendor the crate, adapt modules or defer.
5. Build a minimal sherpa-onnx Rust spike and compare static/shared packaging.
6. Prototype Apalis workflow with SQLite persistence and restart recovery; compare dependency and runtime overhead to a small native implementation.
7. Complete a Jan extension-runtime vs Extism comparison.
8. Evaluate document parsing with actual local sample documents and memory measurements.

## 9. Adoption record template

For every selected component, record:
- Upstream repository, exact commit/tag and retrieval date.
- Exact files/modules adopted and excluded.
- Licence, NOTICE and third-party asset/model obligations.
- Dependency and runtime footprint.
- Local modifications and patch rationale.
- Security capabilities and permission mapping.
- Tests and benchmarks before/after integration.
- Upstream update strategy and replacement criteria.
