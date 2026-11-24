# HLNA v2 — Development and Source Reuse Plan

**Status:** Living plan; source research in progress  
**Repository:** https://github.com/joedanielmsn/HLNA_v2  
**Updated:** 2026-11-24

> Candidates below are research hypotheses, not integration approvals. Before adopting code, pin its revision and inspect exact modules, licence, dependencies, security boundaries, build behaviour and performance. Replace a component whenever evidence shows a materially better option.

## 1. Objective and principles

Build HLNA as a high-quality, local-first desktop assistant by combining the strongest reusable source implementations from mature open-source projects. The result must feel like one coherent product, not a collection of unrelated applications.

1. **Source-code-first reuse:** adopt proven modules or whole application foundations instead of rewriting equivalent functionality.
2. **Best-of-breed:** compare alternatives for important capabilities and select based on evidence.
3. **Replaceability:** no component receives permanent preference because it has already been integrated.
4. **Measure:** benchmark performance, memory, reliability and quality; source reuse does not automatically make software faster.
5. **Unified product:** standardise UX, data models, configuration, events, errors and lifecycle.
6. **Central security:** privileged operations go through a deny-by-default HLNA permission broker. No agent, tool or extension may bypass it.
7. **Local-first privacy:** no automatic telemetry or diagnostic uploads. Network use must be explicit and attributable to a configured provider or enabled integration.
8. **Maintainability:** pin upstream revisions, preserve notices, document local patches and track upstream changes.
9. **Hardware-aware:** target Linux and an NVIDIA RTX 3050 4 GB; minimise idle services, memory use, VRAM contention and unnecessary bundled runtimes.
10. **HLNA v1 remains untouched:** v2 has separate code, app identifier and data/config/cache paths. Never migrate, read, modify or delete v1 or Jan user data.

## 2. Starting decisions

- Desktop foundation candidate: Jan at commit `49a84bdeaebdfc0f36c00f252eb638f516a48432`.
- Architecture baseline: Tauri 2, Rust, React/TypeScript, conditional on a reproducible baseline build.
- Local inference: Ollama-first, initially via `http://localhost:11434/v1`.
- Initial model: `assistant-qwen:latest` (Qwen 3.5 2B Q4_K_M).
- Context: 16,384 tokens default; configurable 4K–16K.
- Avoid bundling a second inference runtime initially if Ollama meets requirements; reconsider only with measured benefit.
- Linux first; other platforms later. Decisions may be revised if testing demonstrates a substantial overall improvement.

## 3. Target architecture

Keep stable internal interfaces between:
- Product shell/UI: chat, conversations, navigation, settings, dashboard and overlays.
- Application core: lifecycle, configuration, persistence, event bus, diagnostics and coordination.
- Model/provider layer: Ollama first; optional remote providers through explicit configuration.
- Agent/workflow layer: planning, tool execution, approvals, cancellation and durable tasks.
- Permission broker: capability grants, consent, scopes, audit and revocation.
- Extension runtime: isolation, host-mediated capabilities and resource limits.
- Knowledge: ingestion, parsing, indexing, retrieval, citations and memory.
- Desktop integration: accessibility, screen capture, window context and user-approved computer interaction.
- Voice: ASR, VAD, TTS and audio-device lifecycle.
- Resource manager: CPU/RAM/VRAM, model lifecycle, task priorities and Gaming Mode.

Prefer in-process Rust modules when safe and practical. Use worker processes when isolation, crash containment or incompatible runtimes justify them. APIs/services remain valid when they offer a genuine advantage; they are simply not the default.

## 4. Source candidate register

All candidates require module-level review and comparison before adoption.

| Capability | Project | Proposed role | Status |
|---|---|---|---|
| Desktop foundation | [Jan, pinned commit](https://github.com/janhq/jan/tree/49a84bdeaebdfc0f36c00f252eb638f516a48432) | UI, provider architecture, storage, extensions, agent/tool foundation | Preferred baseline; build/licence/security validation pending |
| Local inference | [Ollama](https://github.com/ollama/ollama) | Local model runtime through OpenAI-compatible API | Selected initial runtime; validate streaming, cancellation and model/context controls |
| Desktop interaction | [computer-use](https://github.com/lindoelio/computer-use/tree/780bb89e9bb7cfc8a43f999a273b312c832a9a3b) | Evaluate Rust action protocol, Linux backend, accessibility tree, policy and audit modules | Strong candidate; inspect backend dependencies and threat model |
| Voice | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Offline/streaming ASR, VAD and TTS | Strong candidate; benchmark model quality, latency and memory |
| Durable tasks/workflows | [Apalis](https://github.com/apalis-dev/apalis) | Evaluate Rust jobs, retries, persistence and workflow support | Candidate; confirm crate maturity and SQLite fit |
| Plugin runtime | [Extism](https://github.com/extism/extism) | Compare with Jan's extension runtime/Wasmtime architecture | Alternative only; avoid adding a second runtime without clear benefit |
| Document parsing | [Docling](https://github.com/docling-project/docling) | Optional advanced PDF/document worker | Candidate; Python/runtime footprint may be too heavy for always-on use |
| Vector search | Jan vector DB; compare [sqlite-vec](https://github.com/asg017/sqlite-vec) | Local vector storage and retrieval | Prefer Jan path until benchmarked; sqlite-vec licence/release status needs verification |

### Jan foundation

Pinned evaluation source: [Jan commit 49a84bdeaebdfc0f36c00f252eb638f516a48432](https://github.com/janhq/jan/tree/49a84bdeaebdfc0f36c00f252eb638f516a48432).

Inspect selectively:
- `web-app/`: UI and interaction patterns.
- Provider services under `web-app/src/` (exact paths to verify at checkout).
- `src-tauri/`: Tauri/Rust host and plugins.
- `src-tauri/plugins/tauri-plugin-rag/`: RAG plugin.
- `src-tauri/plugins/tauri-plugin-vector-db/`: vector DB plugin.
- `packages/extension-api/` and `packages/extension-runtime/`: extension interfaces/runtime.
- `extensions/`: first-party extensions and examples.

Earlier audit found Jan's llama.cpp engine feature-gated, but some build scripts and Linux bundle resources expect worker binaries. The initial HLNA build must test a no-native-engine configuration, remove only engine-specific bundle requirements and guard unavailable UI/commands. This is unverified until a clean Linux build passes.

Required adaptation:
- Replace Jan app identity, branding and all app data paths with HLNA-owned values.
- Disable/remove Jan data migration and recovery paths that could touch Jan user data.
- Remove analytics/PostHog and default telemetry exporters.
- Disable Jan updater endpoints/signing configuration until HLNA controls updates.
- Narrow Tauri capabilities, CSP, extension grants and network permissions.
- Remove unclear third-party assets (including Studio Feixen fonts unless redistribution rights are proven); use properly licensed alternatives.
- Preserve Apache 2.0 and all applicable third-party notices.

### computer-use candidate

Pinned inspection revision: `780bb89e9bb7cfc8a43f999a273b312c832a9a3b`.

Verified source areas include:
- `src/protocol.rs`: typed action protocol.
- `src/backend/` and `src/backend/linux/`: backend abstraction/Linux implementation.
- `src/tree.rs`: accessibility/tree representation.
- `src/policy.rs`: policy evaluation.
- `src/audit.rs`: audit records.
- `src/browser/`: browser automation behind feature configuration.
- `src/adapters/`: model/provider action adapters.

Correction to an earlier exploratory note: paths such as `src/backend/linux/atspi.rs`, `portal.rs`, `x11.rs`, `src/browser/cdp.rs` and `gate.rs` were not verified as direct source files. Do not use them as an implementation map. Inspect the actual pinned tree and platform implementation before selecting modules.

Potential use is limited to audited protocol/backend/tree/policy/audit functionality. HLNA must add central approvals, scoped permissions, secret-field protection, cancellation and audit controls. Never expose unrestricted shell, input or browser actions.

### Other candidate licence notes

- **sherpa-onnx:** inspected root licence is Apache-2.0. Model weights and bundled assets have separate licences; audit them individually.
- **Apalis:** inspected root licence is MIT. Confirm exact workflow crate/API stability, persistence backend and feature set at a pinned release.
- **Extism:** inspected root licence is BSD-3-Clause. Compare host capability design and runtime cost with Jan's existing extension architecture.
- **Docling:** inspected root licence is MIT. Treat as an optional worker; measure cold start, RAM, CPU, disk and extraction quality. Audit model weights and transitive packages.
- **sqlite-vec:** do not adopt until current release status, repository licence, maintenance, platform support and performance are verified.

## 5. Additional research required

Search and compare candidates for permission broker/policy engine, event bus, memory and knowledge management, browser automation, screen understanding/OCR, workflow editor, notifications, global hotkeys, overlays, dashboard, resource monitoring, NVIDIA VRAM telemetry, Gaming Mode, wake-word/audio routing, backup/export/import and recovery. Do not assume Jan is best for these areas.

## 6. Security, privacy and licensing gates

No source is copied or shipped until:
1. Exact repository, revision, licence and copyright holders are recorded.
2. Root/nested licences, NOTICE files, fonts, icons, assets, models and binaries are checked.
3. Transitive dependencies are inventoried and an SBOM generated.
4. Required notices are preserved and modified upstream files are marked.
5. Maintenance history, issues and security advisories are reviewed.
6. Filesystem, network, process, update, telemetry and permission behaviour is inspected.
7. The minimum required capability set is defined; everything else is denied by default.
8. Static analysis, dependency audits, tests and targeted security checks pass.
9. Adopted source paths, revisions and local patches are documented in `third_party/THIRD_PARTY.md`.

Privacy requirements:
- No automatic analytics, telemetry, crash uploads or OpenTelemetry exports by default.
- No Jan update endpoints or Jan user-data migration.
- No automatic MCP server or extension activation.
- Explicit consent for microphone, screen capture, desktop input, browser control, filesystem access and external network access.
- Network access only for user-configured providers and user-enabled integrations.
- Logs remain local unless explicitly exported by the user.

## 7. Quality and performance gates

Benchmark on the target Linux machine (RTX 3050 4 GB): cold/warm startup; idle/active RAM and CPU; VRAM during inference/voice/vision; chat first-token latency, throughput and cancellation; screen capture/accessibility latency; voice real-time factor; document ingestion throughput and peak memory; workflow overhead and restart recovery; installer size and background process count.

A component must provide meaningful quality or capability improvement without unacceptable performance, reliability, security or maintenance regressions.

## 8. Implementation sequence

**Phase 0 — Research:** expand candidates, inspect exact source modules/licences, pin revisions, map dependencies/conflicts, compare alternatives and select the minimal high-quality initial set.

**Phase 1 — Baseline:** clone pinned Jan into this separate repository, preserve provenance/notices, build and test unmodified Jan on Linux, and record baseline instructions, binary size and resource metrics. Do not customise before the baseline is reproducible.

**Phase 2 — Identity/privacy:** apply HLNA branding and unique identifiers/paths; remove Jan migration, analytics and updater behaviour; audit capabilities, CSP, network and extension permissions; add SBOM/notices.

**Phase 3 — Ollama core:** validate endpoint, model discovery, streaming, cancellation, errors and context controls; configure 16K default and 4K–16K range; test target GPU.

**Phase 4 — Specialist integration:** integrate one audited component at a time (permission/audit, desktop interaction, workflows, voice, document/RAG, extension runtime decision, resource manager). After each batch build, test, benchmark and review security.

**Phase 5 — Product completion:** compare the working app against the Local Assistant 2.0 master plan and prioritise genuine HLNA-specific gaps.

**Phase 6 — Release readiness:** regression/security tests, Linux package/clean-install tests, HLNA v2 backup/recovery, SBOM/licences, documentation and reproducible release process.

## 9. Proposed repository structure

```text
HLNA_v2/
├── README.md
├── plan/
│   ├── HLNA_V2_DEVELOPMENT_PLAN.md
│   ├── SOURCE_ADOPTION_MATRIX.md
│   └── SECURITY_AND_PRIVACY_PLAN.md
├── docs/
│   ├── architecture/
│   ├── decisions/
│   └── operations/
├── third_party/
│   ├── THIRD_PARTY.md
│   └── licenses/
├── scripts/
└── [Jan-derived application source after baseline approval]
```

Exact layout may change to preserve upstream build conventions and make future upstream comparisons practical.

## 10. Decision log

| Decision | Position |
|---|---|
| Keep HLNA v1 untouched; separate v2 repository | Confirmed |
| Best-of-breed, source-code-first reuse | Confirmed |
| Replace inferior components when evidence supports it | Confirmed |
| Jan as initial foundation | Preferred; conditional on build/licence/security validation |
| Ollama as initial local inference | Selected |
| 16K default context, configurable 4K–16K | Selected |
| Linux first | Selected |
| computer-use, sherpa-onnx, Apalis, Extism, Docling, sqlite-vec | Research candidates only |

## 11. Immediate next actions

1. Verify this plan is committed to the new repository.
2. Create a source adoption matrix with exact revisions, paths, licence evidence, dependencies, alternatives and benchmark criteria.
3. Continue module-level research and reject assumptions that do not survive inspection.
4. Select the smallest high-quality initial integration set.
5. Establish the application baseline only after source research is sufficiently complete.

**Quality rule:** if research or testing identifies a substantially better component, compare it objectively and replace the current choice when the overall HLNA improves enough to justify the migration.
