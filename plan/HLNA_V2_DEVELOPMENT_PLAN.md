# HLNA v2 — Development and Source-Reuse Plan

**Status:** Planning baseline — candidate audit in progress  
**Repository:** https://github.com/joedanielmsn/HLNA_v2  
**Last updated:** 2026-11-24  
**Project relationship:** Independent successor to HLNA v1. HLNA v1 remains untouched.

> This document is a living engineering plan. Candidate projects and source paths are not approved for integration until their exact revisions, licences, dependency trees, security properties, buildability and performance have been verified. Do not treat a candidate list as a decision to copy code.

## 1. Product objective

Build HLNA as a high-quality, privacy-respecting, local-first desktop assistant and extensible assistant platform. It should combine mature open-source implementations where they genuinely improve quality, while presenting one coherent product and one consistent permission, resource-management and user-experience model.

The goal is not to maximise the number of imported projects. The goal is the best maintainable product we can reasonably build.

## 2. Non-negotiable engineering principles

1. **Quality over sunk cost.** No framework, application, library or module is protected because it was selected or integrated earlier. Replace it when evidence shows a substantially better option.
2. **Source-code-first reuse.** Prefer adopting and adapting mature source implementations when that provides meaningful control, performance or UX advantages. Use libraries, SDKs, APIs or separate services when they are safer, more reliable, better maintained or materially easier to update.
3. **Reuse before invention.** Search for existing solutions before implementing a capability from scratch. Custom HLNA code should focus on integration, orchestration, compatibility, permissions, resource coordination, genuine gaps and HLNA-specific UX.
4. **Evidence-based selection.** Evaluate actual code, release activity, issue health, security history, licences, transitive dependencies, test coverage, build reproducibility and benchmarks. Popularity alone is not evidence of quality.
5. **One coherent product.** Imported components must fit a shared design system, configuration model, data model, lifecycle and permission architecture.
6. **Security by design.** Deny by default; explicit user approval for sensitive capabilities; least privilege; sandboxing; auditable actions; safe cancellation and recovery.
7. **Privacy by default.** No telemetry or data transmission without explicit, informed user choice. Local logs are acceptable; automatic export is not.
8. **Performance and hardware efficiency.** Avoid unnecessary runtimes, duplicated services, background work and bundled engines. Benchmark on the actual target machine.
9. **Maintainable provenance.** Record upstream repository, exact commit/tag, licence, modifications, patches, notices and update strategy for every adopted component.
10. **Reversible decisions.** Pin dependencies and keep integration boundaries clear enough to replace components without rewriting the entire application.
11. **Test continuously.** Establish upstream baseline tests, HLNA integration tests, security tests and performance budgets before broad customisation.
12. **Do not damage HLNA v1.** HLNA v2 is a separate project, repository, application identifier and data directory. Never migrate, modify, delete or overwrite v1 as part of v2 work.

## 3. Product vision and scope

The Local Assistant 2.0 master plan is a product-requirements source, not a binding technology specification. Its broader vision includes:

- Unified permission broker.
- AI resource manager and gaming mode.
- Event-driven orchestration.
- Voice interaction.
- Desktop awareness and visual/computer automation.
- Workflow recording and automation.
- Configurable dashboard and floating companion.
- Extensible assistant capabilities beyond a chat interface.

The initial release should establish a reliable desktop assistant foundation, then add capabilities in independently testable stages. Do not attempt to ship every long-term feature in the first integration milestone.

## 4. Initial architecture direction

### 4.1 Starting foundation: Jan

**Candidate:** [Jan](https://github.com/janhq/jan)  
**Evaluation baseline:** `49a84bdeaebdfc0f36c00f252eb638f516a48432`  
**Pinned source:** https://github.com/janhq/jan/tree/49a84bdeaebdfc0f36c00f252eb638f516a48432

Jan is the proposed initial desktop foundation because it already provides a Tauri 2 / Rust / React application, conversation UI and storage, provider abstractions, agent and extension infrastructure, and retrieval-related components.

This is a conditional selection, not a permanent commitment. First:
1. Verify the exact commit and all relevant licences.
2. Build and test the unmodified baseline on the target Linux environment.
3. Inventory its application identity, storage paths, network calls, telemetry, updater, permissions, native binaries and third-party assets.
4. Establish a clean HLNA fork/import with complete upstream provenance.
5. Only then begin HLNA-specific changes.

Do not assume source paths mentioned in research notes remain accurate until checked against the pinned tree. Resolve and record exact paths during the source audit.

### 4.2 Inference: Ollama-first

- Primary local inference runtime: Ollama, accessed through its OpenAI-compatible endpoint at `http://localhost:11434/v1`.
- Preferred initial model: `assistant-qwen:latest`.
- Default context: 16,384 tokens.
- User-configurable context range: 4K–16K.
- Avoid compiling or bundling a second llama.cpp inference engine in the initial HLNA build if the Jan code can be cleanly built with that engine disabled.
- Preserve a future option to add another runtime if measured needs justify it.
- Keep remote providers possible, but only when the user explicitly configures them.

The context and model defaults reflect the target machine's successful prior tests. Re-benchmark after integration; do not assume imported runtimes or other background services leave the same VRAM headroom.

### 4.3 HLNA integration/core layer

HLNA-owned Rust modules should provide shared contracts and coordination for:

- Application identity, configuration and lifecycle.
- Unified permission and consent broker.
- Resource manager (CPU, RAM, GPU/VRAM, model and background-task coordination).
- Event bus and workflow coordination.
- Provider/model registry and inference routing.
- Desktop action policy and audit trail.
- Extension capability grants and revocation.
- Common diagnostics, recovery and update policy.
- Design system and unified frontend experience.

These are architectural responsibilities, not a mandate to implement every subsystem from scratch. Each responsibility must be compared with reusable implementations before custom development.

### 4.4 Integration preference

Use this order, choosing the option that best meets product quality:

1. Adopt a complete mature application as a foundation where appropriate.
2. Integrate a source module or library directly when it fits the target architecture.
3. Use an SDK/API or plugin boundary when direct source integration would create excessive coupling or licensing/security risk.
4. Run a separate local service only when isolation, language/runtime requirements or independent lifecycle materially justify it.
5. Implement from scratch only for genuine gaps.

Do not merge entire applications indiscriminately. Extracting code requires understanding its dependencies, assumptions, lifecycle, data model, security boundary and upstream update path.

## 5. Candidate source-code portfolio (provisional)

The following are research candidates, not final selections. Exact module paths, revisions and licence status must be verified before use.

| Capability | Candidate | Initial reason to investigate | Current status |
|---|---|---|---|
| Desktop shell, chat, providers, agent/extension foundation | [Jan](https://github.com/janhq/jan) | Mature Tauri/Rust/React desktop foundation; pinned evaluation commit above | Preferred starting foundation; baseline build and audit pending |
| Local inference | [Ollama](https://github.com/ollama/ollama) | Existing local runtime and OpenAI-compatible API | Use as external local runtime initially; no source merge planned |
| Desktop awareness/computer interaction | [computer-use](https://github.com/lindoelio/computer-use) | Rust-oriented desktop interaction and accessibility implementation | Candidate; repository identity, maintenance, API, platform coverage and licence need independent verification |
| Voice / offline speech | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) | Offline speech recognition, VAD and TTS; Rust and desktop examples | Strong candidate; choose models and benchmark resource use |
| Document understanding | [Docling](https://github.com/docling-project/docling) | Document parsing and structured extraction, including complex documents | Candidate for optional worker; assess Python/runtime cost and model downloads |
| Vector search | [sqlite-vec](https://github.com/asg017/sqlite-vec) | Lightweight SQLite vector search | Candidate only; pre-1.0 maturity requires pinned-version evaluation and comparison |
| Workflow engine | [Apalis](https://github.com/apalis-dev/apalis) | Rust task queues and workflow capabilities | Candidate; verify exact crate maturity, durability semantics, storage backend and integration fit |
| Plugin runtime | [Extism](https://github.com/extism/extism) | Wasm-based multi-language plugin runtime with Rust support | Candidate to compare against Jan's existing extension/Wasmtime architecture; avoid adding a second runtime without a clear benefit |
| Retrieval/RAG | Jan retrieval modules; compare alternatives | Reuse existing retrieval before adding another framework | No final choice; avoid duplicating ingestion, embeddings and vector stores |

### Candidate exclusion / caution list

- [Screenpipe](https://github.com/mediar-ai/screenpipe): do not embed or redistribute until the current licence and commercial-use requirements are reviewed and confirmed compatible.
- [n8n](https://github.com/n8n-io/n8n): its Sustainable Use Licence is not assumed compatible with HLNA's intended unrestricted product distribution. Do not reuse source without legal review and an explicit licensing decision.
- [RAGFlow](https://github.com/infiniflow/ragflow): potentially powerful, but its service/dependency footprint may be disproportionate for a lightweight desktop-first product. Reconsider only if benchmarks show a clear advantage.
- Any project with unclear, missing, source-available or restrictive licensing: no copied source until rights are resolved.
- A candidate being listed here does not imply its current licence, maintenance state or security has already been independently confirmed.

## 6. Capability-by-capability research required

Before selecting source modules, build a comparison matrix for each capability. Include at least two credible alternatives where practical.

### 6.1 Chat and desktop foundation
- Compare Jan against other actively maintained desktop AI clients only if they offer a material advantage.
- Verify conversation persistence, streaming, attachments, Markdown/code rendering, search, export/import, accessibility and offline behaviour.
- Identify which Jan modules can be retained unchanged, adapted or replaced.
- Remove Jan identity, analytics, updater endpoints and unrelated product assumptions.

### 6.2 Agent runtime and tools
- Compare Jan's agent loop and tool execution with dedicated Rust/TypeScript agent frameworks.
- Inspect tool registration, cancellation, timeouts, retries, structured outputs, planning, memory, subagents and failure recovery.
- Ensure all tool calls pass through the HLNA permission broker.
- Prevent arbitrary shell, filesystem, network, browser or desktop access by default.
- Preserve an auditable record of approvals and actions.

### 6.3 Desktop awareness and visual automation
- Compare Linux AT-SPI accessibility, Wayland portals, X11 support, screen capture and browser automation options.
- Prefer semantic accessibility-tree interaction over coordinate-only actions when possible.
- Separate observation permissions from action permissions.
- Require explicit approval for consequential actions; provide a global stop/cancel mechanism.
- Test against supported desktop environments and compositor limitations.

### 6.4 Voice
- Compare sherpa-onnx with other actively maintained offline STT/TTS/VAD implementations.
- Measure cold start, streaming latency, CPU/GPU use, RAM/VRAM and model footprint.
- Make microphone use explicit and visible; do not record or transmit audio without user action and consent.
- Keep voice optional so the core app remains lightweight.

### 6.5 Knowledge and documents
- Compare Jan retrieval, Docling, OCR options, embedding runtimes and vector stores.
- Evaluate PDF, DOCX, XLSX, PPTX, HTML, images, tables and scanned documents.
- Measure indexing time, query latency, retrieval quality, storage growth and memory.
- Keep user documents local by default and make indexing/deletion transparent.
- Avoid running multiple embedding or vector databases without a demonstrated need.

### 6.6 Workflows and event orchestration
- Compare Apalis and alternatives for durable execution, DAGs, schedules, retries, cancellation and observability.
- Distinguish background job queues from user-authored workflows; a queue is not automatically a workflow editor.
- Ensure workflow steps use the same permission broker as interactive tools.
- Make resource-intensive work pauseable and compatible with gaming mode.

### 6.7 Extensions and integrations
- Compare Jan's existing extension architecture with Extism/Wasm and other suitable plugin systems.
- Prefer one plugin runtime unless multiple runtimes are justified by clear compatibility needs.
- Define capability manifests, signatures/provenance, versioning, resource limits, permission prompts and revocation.
- No extension should inherit ambient host privileges.
- MCP servers and tools require explicit user configuration and approval.

### 6.8 Resource management and gaming mode
- Investigate Linux system metrics, GPU telemetry, Ollama model lifecycle and GameMode integration.
- Define policies for model loading/unloading, VRAM pressure, background task priorities and thermal/resource constraints.
- Never assume GPU telemetry APIs are portable; provide graceful fallbacks.
- Benchmark on the target RTX 3050 4GB system.

## 7. Privacy, security and identity requirements

Jan-derived code must be audited and adapted before distribution:

- Use a unique HLNA application identifier, bundle identity, process identity and data directory.
- Never read, migrate, modify or delete Jan user data or HLNA v1 data.
- Remove PostHog/product analytics and analytics consent flows if HLNA's no-telemetry policy remains the requirement; do not merely disable telemetry by default.
- Disable automatic OpenTelemetry export in desktop builds unless a future explicit opt-in design is approved.
- Remove Jan updater endpoints and signing/update configuration. Do not contact Jan update services. Add HLNA-controlled update infrastructure only when ready.
- Audit all HTTP clients, telemetry, diagnostics, crash reporting, model catalogues and remote asset requests.
- Restrict network access to local services and user-configured remote providers/integrations.
- Review every Tauri capability, command allowlist, CSP/connect policy and plugin permission.
- MCP, extensions, shell tools, filesystem tools, browser automation and desktop actions must be explicit, least-privilege and revocable.
- Preserve local diagnostics without automatic transmission.
- Provide clear user-visible permission prompts and audit history.
- Test sandbox escapes, path traversal, symlink handling, prompt injection, tool-output injection, credential leakage and unsafe workflow chaining.

## 8. Licensing, attribution and supply-chain policy

Before copying or shipping any component:

1. Identify the exact upstream repository and immutable commit/tag.
2. Verify the repository licence and licences for the exact subdirectory/package.
3. Inspect all transitive dependencies and bundled assets.
4. Record copyright, attribution, NOTICE and source-disclosure obligations.
5. Verify font, icon, logo, model-weight, sample-data and binary redistribution rights separately.
6. Generate and retain an SBOM and third-party licence inventory.
7. Track local modifications and upstream patches.
8. Define how security fixes and upstream updates will be evaluated.

Jan's root licence is Apache-2.0, but that does not automatically license every third-party asset, logo, font, model or dependency in the repository. Preserve required Apache notices and replace Jan trademarks/branding. Do not redistribute Studio Feixen font assets without clear proof of the required embedding/redistribution rights; prefer an appropriately licensed alternative such as Inter under SIL OFL or system fonts.

No component is approved solely because its top-level repository says MIT or Apache. Verify submodules, generated assets and transitive licences.

## 9. Performance and quality targets

Establish measured baselines before setting hard numeric budgets. At minimum measure:

- Cold and warm application startup.
- Idle and active RAM.
- CPU use while idle, streaming, indexing and running workflows.
- GPU and VRAM use with the configured Ollama model.
- Time to first token and token throughput.
- Conversation load and persistence latency.
- Document indexing and retrieval latency/quality.
- Voice first-audio/first-transcript latency.
- Desktop observation/action latency.
- Background activity and battery/power impact where measurable.

Use the user's RTX 3050 4GB desktop as a primary target, but keep the application usable without a supported NVIDIA GPU. Avoid bundling duplicate inference engines or heavyweight services without evidence.

## 10. Implementation sequence and gates

### Phase 0 — Repository and project hygiene
- Keep this plan in the independent HLNA_v2 repository.
- Establish repository structure, contribution conventions and provenance records.
- Keep HLNA_v1 untouched.
- Decide repository visibility and licensing before publishing copied source. Do not add a top-level licence until the intended distribution model and compatibility review are complete.

### Phase 1 — Source audit and candidate matrix
- Verify Jan pinned commit, build instructions and source layout.
- Audit Jan identity, telemetry, updater, storage migration, permissions, native binaries, fonts and third-party licences.
- Inspect candidate projects at exact revisions.
- Record selected modules, rejected alternatives, reasons, dependency graph and integration approach.
- No broad code import before this gate is complete.

### Phase 2 — Reproducible Jan baseline
- Clone the exact pinned source into a separate working directory/repository history.
- Build and run unmodified Jan on the target Linux environment.
- Run upstream tests and record toolchain/dependency versions.
- Capture startup, idle RAM and baseline feature behaviour.
- Resolve build blockers before customisation.

### Phase 3 — HLNA identity and privacy hardening
- Apply HLNA branding and unique app/data identity.
- Remove Jan telemetry and update-service behaviour.
- Disable legacy Jan data recovery/migration paths.
- Narrow Tauri permissions and network policies.
- Verify that Jan and HLNA v1 data remain untouched.

### Phase 4 — Ollama-first baseline
- Configure Ollama as the primary local provider.
- Verify streaming, cancellation, model discovery, errors and reconnect behaviour.
- Set initial model/context defaults and user configuration.
- Ensure no unnecessary native llama.cpp engine is compiled or bundled.
- Verify agent/tool runtime requirements before removing any supporting binaries.

### Phase 5 — Core capability integrations
Integrate one capability at a time, only after its candidate passes the gates:
1. Unified permission broker and agent tools.
2. Desktop awareness/computer interaction.
3. Voice.
4. Document intelligence and retrieval.
5. Workflow orchestration.
6. Extensions/MCP and integration ecosystem.
7. Resource manager and gaming mode.

Each integration must have a rollback point, tests, licence/provenance record and before/after benchmarks.

### Phase 6 — Unified UX and HLNA-specific capabilities
- Establish design system and consistent settings.
- Integrate dashboard, floating companion and event-driven surfaces.
- Add workflow editor/recorder and user-facing resource controls.
- Compare every unique master-plan feature against existing mature projects before implementing custom code.

### Phase 7 — Release readiness
- Full Linux build and packaging.
- Automated Rust, frontend, integration, security and regression tests.
- Manual accessibility and usability checks.
- Dependency/SBOM/licence review.
- Privacy/network audit.
- Performance comparison against baseline.
- Recovery, uninstall and data-retention checks.
- Release only after all critical issues are resolved.

## 11. Required engineering records

Maintain these documents in the repository:

- `plan/SOURCE_COMPONENT_REGISTER.md` — preliminary source audit with verified findings, candidate dispositions and immediate research priorities. This is the live companion to the plan.

- `plan/HLNA_V2_DEVELOPMENT_PLAN.md` — this document.
- `plan/SOURCE_COMPONENT_REGISTER.md` — upstreams, exact revisions, modules, licence, changes and update policy.
- `plan/ARCHITECTURE.md` — current system architecture and data flows.
- `plan/SECURITY_AND_PRIVACY.md` — threat model, permission model and privacy guarantees.
- `plan/DECISIONS.md` — dated architecture decision records, including superseded decisions.
- `plan/BUILD_AND_TEST.md` — reproducible toolchain, build and validation instructions.
- `THIRD_PARTY_NOTICES.md` and SBOM output — generated and reviewed before distribution.

Do not claim a feature, security boundary, build or benchmark is verified until it has actually been tested.

## 12. Current decisions and open questions

### Current decisions
- HLNA v2 is a separate project and repository.
- HLNA v1 remains untouched.
- Source-code-first reuse is the preferred strategy, but APIs/services remain valid when they produce a better result.
- Jan is the conditional initial desktop foundation at the pinned commit above.
- Ollama is the initial local inference runtime.
- The product must be local-first, privacy-respecting, extensible and resource-conscious.
- A substantially better component may replace an integrated component regardless of prior investment.

### Open validation items
- Verify the exact repository and source paths for every candidate.
- Confirm all licences and asset redistribution rights.
- Complete the Jan baseline build and runtime audit.
- Decide which agent, RAG, extension and workflow components outperform Jan's existing capabilities.
- Confirm Wayland/X11 support and safe desktop-control boundaries.
- Benchmark voice and document processing on target hardware.
- Establish quantitative performance budgets from measured baselines.
- Decide final public/private repository and product licence policy before adding a top-level licence or distributing binaries.

## 13. Decision rule

For every important component, maintain a short comparison record:

- Requirements and measurable acceptance criteria.
- Candidates examined.
- Exact source revisions and licences.
- Security and maintenance assessment.
- Build/integration effort.
- Performance and resource measurements.
- Chosen option and reasons.
- Known limitations and replacement triggers.

**Final rule: HLNA's quality comes first. Existing code, frameworks, architecture choices and previous investments are all replaceable when a better option is demonstrated.**


## 15. Research-backed architecture update — 2026-11-24

This update records the current best-supported direction after inspecting Jan's pinned source and comparing specialist projects. It refines the candidate list; it does not waive the build, licence, security or benchmark gates.

### 15.1 Recommended architecture shape

Use a **modular desktop application**, not a collection of unrelated services:

1. **Tauri 2 + Rust application shell** based on Jan only after the upstream baseline is reproducibly built and audited.
2. **React frontend** for chat, history, settings, dashboard and workflow authoring, with a small typed IPC surface.
3. **Rust domain/core layer** for application lifecycle, storage contracts, model/provider registry, event coordination and permission enforcement.
4. **One central permission broker** through which every agent tool, extension, MCP tool, workflow action and desktop action must pass.
5. **Ollama as the initial local inference process**, called over its local OpenAI-compatible API. Do not link another inference engine into the desktop binary without measured justification.
6. **Existing Jan SQLite/RAG components as the first benchmark baseline**, adapted to HLNA paths and identity. Do not add sqlite-vec or another vector store until a reproducible retrieval test shows a gap.
7. **Optional specialist workers** for expensive document and voice operations. Start them only when needed; keep models/downloads explicit and user-controlled.
8. **One durable workflow/job subsystem**, selected after a comparative prototype. Do not add Apalis and Cloacina together by default.
9. **Existing Jan extension architecture as the initial plugin baseline**. Do not add Extism as a second Wasmtime runtime unless a concrete compatibility/security advantage is demonstrated.

### 15.2 Permission broker — the critical HLNA-owned boundary

The permission broker is not optional glue. It is the security boundary shared by the entire product.

Every capability request should include:
- Requesting principal (user, built-in agent, named extension, MCP server or workflow).
- Requested action and target resource.
- Scope (specific file, directory, application, window, provider or service).
- Risk classification and whether the action is read-only or mutating.
- User grant source, expiry and revocation state.
- Correlation ID for audit and cancellation.

The broker should:
- Default to deny.
- Distinguish observation from mutation.
- Prefer narrow, one-action or one-task grants over broad permanent grants.
- Require fresh confirmation for high-impact or ambiguous actions.
- Support immediate stop and grant revocation.
- Enforce permissions in Rust, not only in the frontend or model prompt.
- Record approvals, denials, execution results and cancellation in a local audit log.
- Be tested against direct IPC calls, alternate agent entry points, MCP calls, nested workflows and tool-output prompt injection.

No plugin, workflow engine or desktop-control backend should be allowed to bypass this broker.

### 15.3 Desktop interaction recommendation

Prototype `computer-use-linux` as the leading Linux implementation candidate. It offers semantic AT-SPI interaction, screenshots and compositor-aware window/input handling, but support is not uniform across every desktop/session. Its latest crate version observed was 0.7.59 (2026-11-20), while the GitHub Releases page surfaced v0.7.31 as its latest release tag; resolve the version/source discrepancy and pin an auditable commit.

Preferred integration experiment:
- First inspect the crate's internal module boundaries and dependency graph.
- Compare importing low-level Rust modules behind HLNA's broker against running a separately supervised local process.
- Do not expose its complete MCP tool set directly to the agent.
- Do not enable its optional shell tool.
- Keep its HTTP MCP listener disabled; use a local process/stdio boundary if a separate process is selected.
- Test AT-SPI, portal screenshots, focus and input on the actual desktop session. Verify both successful and fail-closed behaviour.
- Provide visible activity indication and a global stop mechanism.

The earlier `lindoelio/computer-use` project is no longer the primary candidate. It may remain a reference for narrow implementation ideas only.

### 15.4 Document and retrieval recommendation

Use a two-stage decision:
1. Keep Jan's current parser/vector database as the simple baseline and measure its quality and supported formats.
2. Prototype `docling.rs` 2.86.14 for complex PDFs, OCR, reading order and tables. Compare it with Python Docling and lightweight parsers.

Do not adopt docling.rs's full RAG subsystem initially because it may duplicate Jan's embeddings/vector search. The first integration should normalize parsed documents into a common HLNA document representation, then feed the existing chosen indexer.

Test corpus should include:
- Searchable and scanned PDFs.
- Multi-column layouts and tables.
- DOCX, PPTX, XLSX and HTML.
- Mixed-language documents and Unicode.
- Large documents and malformed files.
- Repeated imports, updates and deletion.

Measure extraction correctness, table fidelity, page/section provenance, indexing time, query latency, RAM/CPU and model footprint. Upstream benchmark numbers are hypotheses until reproduced locally.

### 15.5 Voice recommendation

Prototype sherpa-onnx 2.0.3 as the broad offline speech stack because it provides Rust APIs and upstream Tauri examples for ASR/VAD/TTS. Compare Whisper/whisper-rs for ASR-specific quality and resource use.

Build requirements:
- Pin native libraries and checksums; no hidden build-time downloads.
- Audit each model/voice licence separately from the engine licence.
- Do not bundle large models by default.
- Make microphone use explicit and visible.
- No background recording or remote audio transmission by default.
- Test streaming partial results, interruption, device selection, silence/noise, language support and CPU/GPU load.

### 15.6 Workflow recommendation

Prototype Cloacina and Apalis against the same representative workflows:
- Cloacina appears closer to durable DAG workflows and event-driven computation graphs with SQLite/PostgreSQL persistence.
- Apalis appears stronger as a general background task/worker queue with retries, scheduling and SQLite storage. Its workflow subcrate has a separate maturity status and must not be treated as equally mature as the core queue.
- Neither supplies HLNA's visual workflow editor/recorder or the permission model.

Do not select an engine based on feature lists alone. Test process termination/restart, duplicate delivery, idempotency, retry policy, cancellation, pause/resume, workflow version changes, SQLite contention and resource usage. If Jan's current facilities are sufficient, do not add another engine.

### 15.7 Plugin and extension recommendation

Retain Jan's existing extension runtime as the first baseline, but describe it accurately: at the pinned revision it runs extension JavaScript in browser Web Workers created from blob URLs inside a hidden same-origin frame with a restrictive worker CSP. A host-side dispatcher validates method arguments and grants; Rust mediates extension network access and re-reads grants for each request. This is not a Wasmtime runtime and is not an OS-process sandbox. Preserve it only after testing the browser/WebView threat boundary, worker termination, resource exhaustion, IPC reachability and every host method.

Extism remains deferred. It would introduce a separate Wasm runtime (Wasmtime-backed) rather than duplicate Jan's current JavaScript Worker runtime. Its default feature set includes filesystem and HTTP capabilities; these must not become ambient plugin privileges. If Extism is later selected, build with a minimal feature set and expose only narrowly defined HLNA host functions. Treat extension code as untrusted.

### 15.8 Storage and process boundaries

Keep the initial product local and self-contained:
- Prefer SQLite and existing Rust persistence components where appropriate.
- Use clear per-domain database ownership/migrations; do not let multiple independent subsystems mutate the same tables.
- Evaluate a separate workflow database file if durable workflow writes contend with conversation/RAG workloads.
- Keep credentials out of ordinary application settings and frontend storage; select a platform-appropriate secret store during the security audit.
- Treat Ollama, document/voice workers and optional desktop-control backends as separate trust boundaries with explicit lifecycle, health checks and shutdown.
- Avoid opening network listeners unless a user explicitly enables a feature that requires one.

### 15.9 Revised phase gates

| Gate | Required evidence before proceeding |
|---|---|
| G0 — Requirements | Every master-plan capability mapped to acceptance criteria and a proposed implementation path |
| G1 — Jan baseline | Exact pinned source builds and launches unmodified on target Linux; upstream tests and baseline metrics recorded |
| G2 — Identity/privacy | HLNA paths/identifier verified; no Jan/v1 data touched; no Jan analytics/updater traffic; network calls inventoried |
| G3 — Security core | Permission broker design reviewed; all privileged routes inventoried; deny-by-default tests pass |
| G4 — Core assistant | Ollama chat, persistence, streaming, cancellation and restart recovery pass |
| G5 — Knowledge | Corpus benchmark selects parser/indexer; document deletion and source provenance work |
| G6 — Agents/extensions | All tools route through broker; extension isolation and revocation tests pass |
| G7 — Desktop/voice | Target desktop interaction and voice prototypes pass capability-specific tests; privacy controls verified |
| G8 — Workflows/resources | Durable recovery, idempotency and gaming/resource policies pass tests |
| G9 — Release | SBOM/licences, packaging, security, accessibility, privacy and performance reviews complete |

A failed gate means revise or replace the component; do not proceed merely to preserve schedule or previous work.

## 16. Research references

Primary sources consulted for this update:

- Jan pinned source and changelog: https://github.com/janhq/jan/tree/49a84bdeaebdfc0f36c00f252eb638f516a48432 and https://www.jan.ai/changelog
- Tauri capability model and limitations: https://v2.tauri.app/security/capabilities/ and https://v2.tauri.app/security/
- computer-use-linux source, release and security policy: https://github.com/agent-sh/computer-use-linux, https://docs.rs/crate/computer-use-linux/latest and https://github.com/agent-sh/computer-use-linux/blob/main/SECURITY.md
- sherpa-onnx Rust API and v2.0.3 release: https://docs.rs/sherpa-onnx/latest/sherpa_onnx/ and https://github.com/k2-fsa/sherpa-onnx/releases/tag/v2.0.3
- Docling Rust port and releases: https://github.com/docling-project/docling.rs and https://github.com/docling-project/docling.rs/releases
- Apalis queue/workflow documentation: https://docs.rs/apalis/latest/apalis/, https://docs.rs/apalis-workflow/latest/apalis_workflow/ and https://docs.rs/apalis-sqlite/latest/apalis_sqlite/
- Cloacina workflow documentation: https://docs.rs/cloacina/latest/cloacina/ and https://colliery-io.github.io/cloacina/
- Extism feature configuration: https://docs.rs/crate/extism/latest/features and https://extism.org/docs/concepts/configuration/

Research is a point-in-time snapshot. Before importing a dependency, re-check the current upstream revision, release, licence, security advisories and dependency tree.


### 15.10 Desktop foundation alternatives checked

Jan remains the conditional starting foundation because it most closely matches HLNA's chosen Tauri 2 + Rust desktop architecture while already containing chat, provider, agent and extension infrastructure. This conclusion is comparative, not absolute.

- **AnythingLLM** is the strongest broad feature reference: MIT-licensed, with a React frontend, Node/Express server and separate document collector. Its RAG/document pipeline is worth inspecting for specific gaps, but adopting the full app would introduce another application/server architecture and runtime.
- **GPT4All** is a mature MIT-licensed local AI desktop product built around Qt/C++ and its own inference/backend stack. It is a valuable UX and local-model-management reference, but not a natural foundation for the Rust/Tauri/Ollama-first design.
- **Chatbox Community Edition** is GPL-3.0. Review its obligations against HLNA's eventual distribution/licence before copying code; its client UX can still inform feature research.
- **Open WebUI** is a strong web application, but its newer licence includes a branding condition. That makes it a poor foundation for a fully rebranded HLNA product unless those terms are deliberately accepted. The older BSD-3-licensed code through v0.6.5 is not automatically a better choice because it is an older baseline.
- **OpenYoke** demonstrates a very lean Tauri/Rust/Ollama client and useful branching-chat UX, but current adoption/maintenance evidence is not sufficient to replace Jan as the complete foundation.
- **Ambient** demonstrates Tauri/Rust desktop awareness and agent features, but its bundled llama.cpp and cloud-service assumptions do not match the initial Ollama-first, privacy-first architecture.

The source component register contains the comparison references. No alternative is ruled out forever: a clean baseline build, deeper module inspection or measured prototype may change the foundation decision.


### 15.11 Exact agent-permission and identity-migration audit

A deeper pass over the pinned Jan source refines the earlier security notes:

- The desktop agent path is not the same as the CLI/API orchestration path. Jan's desktop chat tool loop is driven in TypeScript (custom-chat-transport.ts) and invokes Rust IPC commands in src-tauri/plugins/tauri-plugin-agent-tools/src/commands.rs.
- The desktop execute_tool implementation resolves the tool gate in Rust using ToolPermissions::default(). At the pinned revision, PermissionDefault defaults to ReadOnly. The desktop path also checks workspace roots and hidden paths.
- Desktop writes are confined to a per-thread ephemeral workspace; writing to an attached user folder is a separate opt-in path. A write escaping the workspace is refused. The desktop shell is exposed only when an enforcing OS sandbox is available; otherwise it is refused rather than run unconfined. Escalation outside the sandbox is refused on this surface.
- This is a useful security baseline to preserve, not proof that all Jan surfaces are safe. The CLI has a separate permission/configuration path, and MCP server consent, extension APIs, updater, web search, and other privileged routes still need independent tracing. HLNA's broker remains necessary to unify policy across all surfaces.
- Correction to the earlier wording: the pinned loop.rs accepts a ToolPermissions value; it does not itself call ToolPermissions::allow_all(). The constructor is defined in the permission module and appears in tests at this pinned ref. Do not attribute a permissive default to the shared loop without tracing the caller.
- Jan's app configuration migration is a particularly important identity boundary. core/app/commands.rs searches legacy Jan bundle-ID/package-name locations, copies a legacy settings file into the canonical location, and then attempts to remove the old copy. HLNA must disable/replace this migration and recovery logic; changing only the bundle identifier, product name, or data-root environment variables is not sufficient. No HLNA first-run or migration code may probe, copy, rename, or delete Jan/v1 data.
- The pinned Tauri config permits broad HTTP(S) connectivity, includes PostHog hostnames in CSP, and configures Jan updater endpoints. The default capability file includes shell spawning, broad HTTP URL scopes, updater and multiple powerful plugins; its opener path scope is broad. HLNA must remove analytics/updater integrations and replace inherited capabilities/CSP with a small, explicit per-window allowlist.
- Jan's scripts/download-bin.mjs downloads Bun and uv from floating latest URLs and fetches sqlite-vec release assets dynamically. HLNA's build should pin tool versions and exact asset hashes/signatures, cache verified artifacts, and make network access during builds explicit. The sqlite-vec download is optional and the source code documents a linear-search fallback.

Pinned source paths:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/agent/loop.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/permissions.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/gate.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/app/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/tauri.conf.json
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/capabilities/default.json
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/scripts/download-bin.mjs



### 15.12 Extension-runtime architecture and security refinement

The pinned Jan source audit resolves an important ambiguity: Jan's extension runtime is **not Wasmtime-based** at commit 49a84bdeaebdfc0f36c00f252eb638f516a48432.

- The host creates one classic JavaScript Web Worker per extension from a blob URL. Workers are created inside a hidden same-origin frame carrying a restrictive CSP: default-src none, script-src wasm-unsafe-eval, worker-src blob. This blocks ordinary network primitives and eval while permitting WebAssembly compilation.
- The worker prelude strips selected globals as a second layer. Extension host calls cross a message/dispatcher boundary; the dispatcher validates argument shapes and checks each method's permission requirement. The worker can be terminated and pending host work is cancelled.
- The Rust Tauri plugin mediates installed-extension HTTP requests. It re-reads grants from the persisted registry for each request, uses a client without a cookie store and without automatic redirects, rejects transport headers, restricts methods and request sizes, caps response bodies, and refuses the app's own local API port. Redirects are checked one hop at a time by the host.
- The HTTP implementation documents accepted risks: DNS resolution is not pinned/validated against the granted hostname, and system/environment proxy settings may route traffic through a configured proxy. These risks need explicit HLNA policy and tests, not silent assumptions.
- A browser Worker is a separate JavaScript execution context, not an independent OS process or a memory/CPU sandbox. The WebView/browser engine remains in the trusted computing base. A compromised renderer, engine vulnerability, unbounded CPU/memory use, or a privileged host API defect may cross the intended boundary. Do not describe this as equivalent to a Wasmtime/WASI sandbox or an OS sandbox.
- Preserve Jan's current runtime as a prototype only after auditing every dispatcher method, install/update path, manifest validation, signature/key handling, worker lifecycle, message-size/rate limits, resource exhaustion, Tauri IPC reachability and cancellation. Evaluate a separate OS process or Wasmtime/WASI worker only if the threat model or tests show the Worker model is insufficient.
- Extism would add a separate Wasmtime-backed WebAssembly runtime. Its default features still require disabling or tightly controlling ambient filesystem/network and exposing explicit host functions.

Pinned source:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/extensions/worker-runtime.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/extensions/dispatcher.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/web-app/src/lib/extensions/host-api.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/http.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/install.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/state.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/permissions.rs



### 15.13 Vector database audit and adoption safeguards

Jan's SQLite vector implementation remains a useful baseline, but the pinned code has several issues HLNA must address before reuse:

- **Native extension provenance:** sqlite-vec is loaded as a native SQLite extension. The current loader searches an environment override, development paths, executable-relative paths, common system directories and finally bare library names. Loading an arbitrary native library is code execution in the application process. HLNA should load only a bundled, version-pinned, hash-verified artifact from a canonical application resource directory; reject user-controlled/system/bare-name search paths by default, and disable extension loading again immediately after the trusted module is loaded if the SQLite API permits.
- **ANN cleanup consistency:** insertion writes embeddings into both the ordinary chunks table and the sqlite-vec virtual table. The inspected delete_file and delete_chunks paths delete from chunks but do not visibly delete corresponding rows from chunks_vec. This can leave orphaned ANN entries, waste storage and create correctness hazards if SQLite rowids are later reused. Add explicit vector-row deletion in the same transaction or use a schema/design that guarantees synchronized deletion. Add tests for repeated insert/update/delete/reopen cycles and rowid reuse.
- **Embedding dimension/model lifecycle:** the virtual table is created with a fixed vector dimension. The current extension attempts to tolerate ANN insert failures and retain linear-search availability when dimensions differ. HLNA should record embedding model identity, revision, dimension and preprocessing/chunking version per index. A model change should trigger a staged rebuild into a new collection, verify it, then atomically switch; never silently mix dimensions or destroy the only existing index.
- **Avoid duplicate embedding work:** the current project-ingestion path calls embedTexts once to discover dimension and again to insert the chunks. Retain and reuse the first embedding batch when valid, avoiding a second inference pass. Benchmark this on the target GPU/CPU.
- **Chunking:** Jan's Rust chunk_text helper splits by Unicode character count, not the active embedding model's tokenizer. Its extension applies heuristics and token-count checks around that helper. HLNA should use tokenizer-aware chunking with configurable overlap and preserve page/section provenance; evaluate document-specific structure-aware splitting.
- **Database lifecycle:** collection names are mapped to individual SQLite files; conversation/thread and project collections are separated. Keep that ownership model only if lifecycle tests prove collection deletion, project deletion, file re-import and backup/restore are consistent. Define explicit SQLite busy timeout, WAL/checkpoint and backup policy before introducing concurrent background indexing.

The vector implementation is therefore still a benchmark baseline, not yet an approved production component. The immediate priority is correctness and native-extension provenance, not replacing SQLite with a new vector database prematurely.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-vector-db/src/db.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-vector-db/src/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/extensions/vector-db-extension/src/index.ts
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/extensions/rag-extension/src/index.ts



### 15.14 Extension signing and trust model — deeper audit

Jan's pinned extension catalogue has user-pinned Ed25519 signing keys, strict detached-signature verification over exact index bytes, signed-index freshness/expiry checks, SHA-512 SRI for extension tarballs, and manifest ID/version/permission matching before the user grants permissions. This is a positive baseline for HLNA's extension supply chain. Jan does not ship a universal trust key: the user pins the source key. Unsigned sources and local packages remain possible and must be clearly distinguished. An optional provenance-attestation URL is displayed as reported by the source but is not verified by Jan.

HLNA should preserve the separation between:
- publisher identity/integrity (signature and pinned key),
- package integrity (digest),
- build provenance (independently verified attestation),
- runtime permission (HLNA broker grant),
- and actual behaviour (sandbox and host API enforcement).

A valid signature does not make code safe. Test key rotation, revocation, expiry, rollback, downgrade, package extraction limits and update permission diffs. Every extension action must still pass through the broker at execution time.

Pinned source:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/signature.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/index.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-extensions/src/install.rs

### 15.15 Jan background-task capability boundary

Jan's Cowork implementation already offers subagent dispatch, task/todo state, and bounded background monitors. Finished subagent state is persisted with Cowork sessions. Monitor execution itself is held in in-memory Rust task sets and client-side lanes; the inspected implementation does not establish durable monitor recovery after application-process termination.

Therefore:
- Reuse Jan's Cowork UX, subagent and task primitives where useful.
- Do not treat a persisted task transcript or completed-subagent record as proof that an interrupted execution can resume.
- Do not assume Jan provides a general-purpose durable, versioned workflow DAG engine.
- Keep Cloacina and Apalis as prototype candidates only if HLNA needs restart-safe automation beyond these facilities.

### 15.16 Workflow-engine comparison update

Cloacina 0.12.0 is currently the stronger durable-DAG prototype candidate: embedded Rust library, Apache-2.0, SQLite/PostgreSQL, durable workflow graphs, retries, recovery, atomic task-completion commits and heartbeat-driven stale-claim recovery. Its separate server/control-plane mode is not needed for the initial desktop product.

Apalis 1.2.0 is a strong general job-queue comparison: MIT-licensed core with retries, timeouts, idempotency, scheduling, priorities and observability. The apalis-sqlite backend documents persistent jobs, retry/backoff, heartbeat/orphan recovery, delayed jobs and priorities. Its workflow crate is now listed in the 1.2.0 ecosystem; test its actual semantics rather than relying on earlier maturity assumptions.

Jan's in-memory monitor tasks and persisted Cowork session state are a useful third baseline, but not an equivalent durable DAG system. Compare Cloacina and Apalis with identical crash/restart, duplicate-delivery, idempotency, cancellation, pause/resume, retry, scheduled-job, workflow-version and SQLite-contention tests. Do not adopt both automatically.

### 15.17 Docling.rs deployment and model policy

Docling.rs v2.86.14 is an MIT Rust workspace with separate crates for document conversion, PDF/ONNX processing, ASR, FFI and optional RAG/server features. Declarative converters for Office/HTML/EPUB formats can run without the ML model bundle; advanced PDF layout, OCR, tables and ASR require additional model/runtime assets.

The compact Linux CLI archive is not the full ML-enabled footprint. The model catalogue includes assets under multiple separate licences (including Apache-2.0, MIT, CDLA-Permissive-2.0 and BSD-3-Clause for PDFium), with source revisions and digest/provenance records. HLNA must keep model licensing and hashes alongside each downloaded asset.

Prototype simple non-ML conversions first. Add the ML/PDF path as an optional, explicitly downloaded capability, then benchmark CPU/RAM/GPU coexistence with Ollama. Do not enable Docling's RAG subsystem by default; normalize its document output into HLNA's selected indexer.

### 15.18 Voice native-build reproducibility

The sherpa-onnx 2.0.3 Rust API supports streaming/offline ASR, TTS, VAD and related speech functions. Its static Rust build can automatically download a native archive when SHERPA_ONNX_LIB_DIR is not configured. HLNA builds must instead prefetch a pinned native archive, verify its checksum, and point the build at the verified local copy. Model and voice licences remain independent of the Apache-2.0 engine licence.

### 15.19 Computer-use-linux provenance update

Current repository main reports computer-use-linux 0.7.60 and Rust 1.95; its changelog includes recent background input changes for GNOME and KDE Wayland. Source mapping is now established: GitHub commit 31d34d65becd36a5796c5cc13c01fa4fce62c46a contains Cargo/package version 0.7.60 and a changelog comparison link for v0.7.59...v0.7.60. The earlier Releases-page result showing v0.7.31 was stale/incomplete. Before adoption, verify the published crates.io archive checksum and release binaries against this exact commit and reproduce the build. Keep desktop observation and mutation behind separate broker grants, visible activity and immediate revoke/stop. Keep the optional HTTP MCP listener disabled; use a supervised local process if the component is adopted.

### 15.20 Updated research conclusions

- Jan remains the conditional desktop foundation; build and test the unmodified pinned baseline before changing it.
- Jan's extension signing controls are worth retaining as a starting point, while the Worker runtime still needs resource/isolation review.
- Jan's Cowork task facilities cover agent-oriented background activity but do not replace durable workflow orchestration.
- Cloacina is the leading durable-DAG prototype; Apalis is the job-queue comparison.
- Docling.rs should be tested in two stages: no-ML converters first, optional model-backed PDF/OCR later.
- sherpa-onnx remains the voice prototype, subject to pinned native dependencies and model licensing.
- computer-use-linux remains the leading Linux desktop-control prototype, pending source provenance and target-compositor tests.

All choices remain provisional until reproducible tests on the target Linux machine. No third-party application source has been imported, and HLNA v1 remains untouched.


### 15.21 Voice-engine alternatives and model licensing

Keep whisper.cpp/whisper-rs 0.16.0 as an ASR-only benchmark against sherpa-onnx. whisper.cpp supports CPU execution and optional NVIDIA/Vulkan acceleration; whisper-rs provides Rust bindings but does not provide the same complete ASR/VAD/TTS breadth as sherpa-onnx. Avoid shipping both engines unless measured quality or performance requires it.

Piper is not a default choice: the current OHF-Voice engine is GPL-3.0-or-later, its current focus is Python, and its voice models have independent licences and potentially inherited dataset restrictions through their fine-tuning chains. Review the complete MODEL_CARD/training lineage for any voice considered; a voice's display name or its immediate dataset licence is not enough. Reconsider only after HLNA's final distribution/licensing model and the integration route are settled.

sherpa-onnx remains the unified voice prototype because it exposes Rust APIs for streaming/offline ASR, TTS and VAD. Every selected model/voice still needs its own provenance, checksum and licence record. The engine licence does not grant rights to model weights or voice recordings.

References:
- https://github.com/ggml-org/whisper.cpp
- https://docs.rs/crate/whisper-rs/latest
- https://github.com/OHF-Voice/piper1-gpl
- https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/LICENSING.md
- https://github.com/OHF-Voice/piper1-gpl/blob/main/docs/COMMERCIAL_USE.md


### 15.22 Jan cross-surface permission defaults — critical integration constraint

A source-level audit of the pinned Jan commit found materially different defaults across surfaces:

- The general headless CLI/TUI sets auto_approve = !safe; without --safe, writes, shell and MCP calls that would otherwise prompt are auto-approved.
- CLI shell sandboxing is separate and off by default unless enabled by a flag or configuration. With sandboxing enabled, CLI defaults still allow network and home-directory reads unless separately restricted.
- The CLI agent.toml [tools] allow/deny/default policy is not the desktop policy. The project parser explicitly states permissions_from is CLI-only; desktop tool gating is implemented by the Tauri plugin.
- CLI default = read-only still advertises opaque MCP tools. It governs built-in tool categories; it does not make third-party MCP tools read-only. Explicit deny policy or a safe approval flow is required.
- The CLI auto-approval setting is inherited by dispatched subagents. A wrapper cannot assume child runs have a stricter policy than the parent.

HLNA must not launch Jan's general CLI agent with default options. If used at all, every relevant flag/config must be explicitly set, and the HLNA broker must remain the final authority outside the process. Prefer the narrower jan mcp serve surface for tool reuse where practical.

### 15.23 Positive Jan MCP security patterns

Jan's desktop MCP client resolves each call to a named server and connection generation; it refuses calls if the server was replaced after tool discovery. Before execution it consumes a one-use authorization bound to the exact thread, call ID, tool, server and origin. Replays and mismatches are refused. Calls have timeout, cancellation and output truncation. Saved grants are separate from thread and one-shot grants; only explicit "Allow always" is persisted. The global allow-all-MCP setting is a persisted user opt-in, while strict extension/attached-folder calls remain ask-every-time.

Jan's separate jan mcp serve endpoint is narrower by default:
- filesystem write and shell tools are omitted unless explicit startup flags opt them in;
- prompts cannot be answered by an external peer, so operations outside the explicit served set or outside the fixed project root are refused;
- shell sandbox defaults on and network defaults off (subject to project config);
- Jan's own home is hidden from served tools;
- HTTP binds to loopback and requires a 256-bit random bearer token, compared in constant time.

HLNA should reuse the one-use, call-bound authorization pattern and generation-bound server identity, but extend it with broker-owned resource scopes, expiry, caller identity, action class, audit and revocation generation. All MCP, extension, workflow, subagent, desktop-control and CLI routes must converge on one Rust-side broker.

Pinned source:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/consent.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/mcp/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/cli/mcp_serve.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/src/core/mcp/server/http.rs

**Security gate update:** Before HLNA enables any Jan CLI/agent automation, create explicit tests proving that no invocation can auto-approve, disable sandboxing, inherit unrestricted network/home access, or bypass the central broker. Test parent-to-subagent inheritance and every IPC/API/MCP route.


### 15.24 Document-processing shortlist expanded

The document-processing source audit now includes the current Docling.rs release and two additional Rust candidates.

**Docling.rs v2.88.1** (2026-11-24) supersedes the earlier v2.86.14 baseline. Its broad Rust workspace, optional ML pipeline, pure-Rust default PDF renderer, and digest-bound model manifest with upstream revisions/licences and immutable model snapshots make it the mature broad-feature candidate. Important build gate: the ML-enabled docling-onnx crate enables ort's download-binaries feature, so the prebuilt ONNX Runtime artifact must be pinned, hash-verified and cached separately from Cargo source dependencies. Avoid its optional dynamic runtime loader initially because it searches environment, model-directory and system library locations.

**docparse-rs** is a new Apache-2.0 Rust candidate (workspace version 0.1.0) supporting 12 formats and a structured, positioned document IR with page/bbox citations. It advertises a no-model deterministic core and optional OCR/layout/table/formula enhancements. It is promising for a lightweight multi-format baseline, but is much less mature than Docling and its published performance/quality claims need independent reproduction. Its current PP-OCRv6 fetcher uses floating Hugging Face main URLs and does not verify cryptographic hashes; HLNA must replace that with pinned, digest-verified assets. Its MCP tools accept arbitrary local paths without an HLNA project-root gate, and its unauthenticated REST server can be configured to bind beyond loopback. Do not expose its MCP/REST interfaces directly. If prototyped, call the library only after broker path authorization, or supervise it under a restrictive OS sandbox.

**Firecrawl pdf-inspector 0.1.7** is MIT-licensed and Rust, focused on fast classification and extraction of born-digital PDFs with positioned text, reading order and tables. It is not a multi-format or OCR solution. Keep it as a specialist PDF fast-path benchmark; add it only if it materially improves native-text PDF latency/quality over the selected broad parser.

**DocSlicer** is a Python parser for PDF/DOCX/PPTX/HTML whose associated BizDocBench reports a strong score on 77 business documents. The benchmark is maintained by the same publisher and explicitly excludes scanned documents, handwriting and OCR, so treat it as a useful external test reference, not independent proof of superiority. DocSlicer is dual-licensed AGPL-3.0-only or commercial; a closed/proprietary distribution needs a careful licence decision and potentially a commercial agreement. Do not integrate its code by default.

### 15.25 Document parser acceptance and security tests

The parser comparison now includes Jan's baseline, Docling.rs no-ML and ML paths, docparse-rs default and optional paths, and pdf-inspector as a PDF specialist. DocSlicer may be used as a benchmark reference if its corpus/methodology is independently reviewed; its code is excluded unless licence compatibility is resolved.

Evaluate a licence-cleared corpus covering born-digital/scanned/mixed PDFs, multi-column layouts, complex tables, CJK/RTL/Unicode, DOCX, PPTX notes/charts, XLSX, HTML, malformed/hostile files and very large documents. Score each format independently. Measure extraction accuracy, reading order, heading hierarchy, table fidelity, page+bbox citations, hidden-text handling, coverage, throughput, cold start, peak RSS, CPU/GPU memory, disk footprint and effect on concurrent Ollama inference.

Security requirements:
- All parser input paths must be authorized by the HLNA broker before opening.
- No parser MCP/REST server may receive unrestricted filesystem access.
- No unauthenticated service may bind to a non-loopback interface.
- Model files, native runtimes and parser binaries require pinned source revisions, cryptographic hashes, licence records and offline/cache-aware installation.
- Apply input size, page count, archive expansion, decompression, CPU-time, memory and cancellation limits. Test malformed PDFs and Office ZIP containers.
- Treat extracted document text as untrusted prompt-injection content; preserve provenance and hidden-text flags, and never treat document instructions as permission grants.

No document parser has been selected for production. No application source has been imported; HLNA v1 remains untouched.


### 15.26 Corrected Jan desktop tool-permission finding

**Final source-level interpretation:** Jan's `ToolPermissions::default()` calls `allow_all()`, setting `PermissionDefault::Allow`. However, `ToolPermissions::is_allowed(name)` only checks explicit `allow` and `allow_write` pattern lists; it does not consult the default enum. The desktop `execute_tool_inner` passes this default object to `resolve_decision`, but the gate's early allow branch is based on explicit patterns. Therefore, the Allow-valued default does **not** bypass capability-specific read/write/exec handling. The default's separate significance includes MCP tool advertisement. Earlier notes that called the desktop default ReadOnly were wrong; the subsequent interpretation that it short-circuits every capability prompt was also wrong.

The desktop caller then handles decisions with separate safeguards: writes inside its ephemeral thread workspace are allowed because the workspace is disposable and shell is confined; writes outside approved roots are refused; shell requires an enforcing OS jail; escalation is refused; read-only and writable attachments have separate scope. The code path should still be tested end-to-end, especially handler-level filesystem checks, symlink races, attachments, hidden Jan-home access, jail enforcement and IPC exposure.

Pinned sources:
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/permissions.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/commands.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/gate.rs
- https://github.com/janhq/jan/blob/49a84bdeaebdfc0f36c00f252eb638f516a48432/src-tauri/plugins/tauri-plugin-agent-tools/src/tools/sandbox.rs

### 15.27 Distinct MCP execution surfaces and API orchestration

Jan has materially different MCP paths:
- Desktop agent MCP uses one-use authorization bound to thread/call/tool/server/origin, server-generation checks, timeout, cancellation and output caps.
- Jan MCP server mode reuses built-in schemas, handlers and the shared gate. It defaults to read/search/memory/skill/web; filesystem writes and shell are opt-in; paths are confined to one fixed served root; shell is sandboxed; hidden Jan home is refused.
- The Local API Server's `/orchestrations` endpoint collects MCP tools and calls `execute_mcp_tool_calls` directly. That routine resolves server route/generation and invokes `service.call_tool` with timeout/output truncation, but does not use desktop one-use consent or per-call prompts. The route requires the explicit `enable_server_tool_execution` setting. This is a distinct headless authorization boundary.
- MCP server activation and child-process lifecycle are separate from per-call authorization. Configured MCP servers must be treated as untrusted.

HLNA requirement: all these entry points must converge on the same Rust broker at the side-effect boundary. Enabling headless tool execution must not grant blanket permissions or bypass resource/action checks.

### 15.28 Authorization policy and OS sandbox research

New candidate: **Cedar** (Apache-2.0 Rust policy engine, https://github.com/cedar-policy/cedar). It offers schema-validated RBAC/ABAC policy evaluation, deny-by-default semantics, a validator and automated-reasoning tooling. Prototype it as a policy evaluator, not as the broker or enforcement mechanism. HLNA must still authenticate the caller, construct trusted principal/action/resource/context attributes, and enforce the decision immediately before the side effect. Compare with a small typed Rust policy implementation; Cedar is only worthwhile if it improves policy expressiveness and auditability without unnecessary complexity.

Layered Linux building blocks:
- Rust Landlock 0.4.7 (MIT/Apache-2.0, https://github.com/landlock-lsm/rust-landlock) for kernel-enforced filesystem and supported network/IPC restrictions.
- cap-std 4.0.3 (https://github.com/bytecodealliance/cap-std) for capability-oriented filesystem APIs inside Rust code; it is not a process sandbox.
- Jan already includes platform-specific jail machinery. Audit and benchmark it before replacing it. Any unavailable/non-enforcing backend must fail closed for operations requiring confinement.
- Other newly surfaced sandbox crates/projects remain research-only until source, maintenance, threat model, license, kernel compatibility and adversarial tests are reviewed.

### 15.29 Expanded workflow-engine comparison

Beyond Cloacina and Apalis:
- Acts 0.25.0 (https://docs.rs/acts/latest/acts/) supports YAML workflows, embedded or server mode, durable transactional transitions, branches, joins, subflows, timers and human/message actions. Promising declarative candidate; verify maintenance, licence, package execution model and storage backends.
- Durare 0.5.0 (https://github.com/SamuelXing/durare) is a DBOS-compatible Rust durable execution library with SQLite/Postgres providers and checkpoint/recovery; Apache-2.0/MIT. Smaller community; code-first, not a visual editor.
- Cloacina 0.12.0 remains an embedded typed DAG candidate with SQLite/Postgres, retries/recovery and content-versioning.
- Apalis 1.2.0 remains a general background job queue; its workflow add-on is a separate release candidate and should not be treated as equally mature.
- Prototype one primary workflow engine, not all in production. Test external side-effect idempotency, crash windows, retries, cancellation, pause/resume, workflow version migration and SQLite contention. Durable workflow state alone cannot guarantee exactly-once effects in external services.

### 15.30 Voice integration refinement

- sherpa-onnx 2.0.3 remains the leading unified offline ASR/TTS/VAD candidate, with Rust bindings for streaming/offline recognition, synthesis, VAD, diarization, punctuation and denoising.
- Its Rust crate statically links by default and may download a matching native archive during build if `SHERPA_ONNX_LIB_DIR` is unset. Pin the release, archive checksum, build features and cache; no invisible floating downloads.
- speechkit 0.5.0 (https://docs.rs/speechkit/latest/speechkit/) is a Rust convenience facade over sherpa-onnx plus optional cloud providers/audio devices. It may reduce glue code but does not remove native/model provenance requirements. Disable cloud features in local-first builds.
- whisper-rs 0.16.0 (Unlicense) remains an ASR-only comparison with optional CUDA/Vulkan/OpenBLAS paths; it is not a unified TTS/VAD stack.
- Benchmark actual target hardware and target languages, including CPU fallback, RAM/VRAM, cold start, latency and concurrent Ollama inference. Each voice/model has its own licence and checksum record.
