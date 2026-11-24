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
