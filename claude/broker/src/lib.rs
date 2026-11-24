//! HLNA permission broker core (Day 2).
//!
//! A small, dependency-free policy engine meant to live in the trusted Rust host.
//! It decides Allow / Ask / Deny for a request and keeps a redacted audit trail.
//!
//! What this crate does NOT do (be honest about the limits):
//! * It is not wired into Jan's tool/MCP call paths. Whoever integrates it must route
//!   every privileged operation through `Broker::evaluate` in the Rust backend.
//! * `component` must come from trusted host code (e.g. the MCP server registry entry),
//!   never from model output, plugin messages or the webview.
//! * Path checks resolve symlinks at check time. A caller must still open files in a way
//!   that avoids check/use races (e.g. `cap-std`, `openat2` with RESOLVE_BENEATH, O_NOFOLLOW).
//! * Prompts shown to the user are not a security boundary; this decision is.

use std::fs;
use std::path::{Component, Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Risk {
    Low,
    Medium,
    High,
    Critical,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Access {
    Read,
    Write,
    Execute,
    Delete,
    Network,
}

#[derive(Debug, Clone)]
pub enum Target {
    Path(PathBuf),
    Host(String),
    Other(String),
}

#[derive(Debug, Clone)]
pub struct Request {
    /// Trusted identity of the requester, e.g. "mcp:filesystem".
    pub component: String,
    /// Operation name, e.g. "fs.read_file".
    pub capability: String,
    pub access: Access,
    pub target: Target,
    /// Human-readable arguments for the prompt and the audit log (redacted on storage).
    pub args_summary: String,
    pub risk: Risk,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Decision {
    Allow { grant_id: u64 },
    Ask { prompt: String },
    Deny { reason: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    /// Standing grants apply to Low/Medium risk. Default.
    Policy,
    /// Only one-shot grants (created by an explicit user approval) allow anything.
    AskEveryTime,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Scope {
    PathPrefix(PathBuf),
    /// Exact host match, no wildcards.
    Host(String),
    Exact(String),
}

#[derive(Debug, Clone)]
pub struct Grant {
    pub id: u64,
    pub component: String,
    pub capability: String,
    pub access: Access,
    pub scope: Scope,
    pub expires_at: Option<SystemTime>,
    pub one_shot: bool,
}

#[derive(Debug, Clone)]
pub struct AuditRecord {
    pub unix_secs: u64,
    pub component: String,
    pub capability: String,
    pub access: Access,
    pub target: String,
    pub args: String,
    pub outcome: String,
}

pub struct Broker {
    mode: Mode,
    grants: Vec<Grant>,
    protected: Vec<PathBuf>,
    stopped: bool,
    audit: Vec<AuditRecord>,
    next_id: u64,
}

impl Broker {
    /// `protected_roots`: paths no request may ever touch, even with a grant
    /// (real Jan profiles, HLNA v1, system credential stores, ...).
    pub fn new(mode: Mode, protected_roots: Vec<PathBuf>) -> Self {
        let protected = protected_roots
            .into_iter()
            .map(|p| p.canonicalize().unwrap_or(p))
            .collect();
        Broker { mode, grants: Vec::new(), protected, stopped: false, audit: Vec::new(), next_id: 1 }
    }

    pub fn set_mode(&mut self, mode: Mode) {
        self.mode = mode;
    }

    /// Emergency stop: deny everything until `resume`. Grants are kept.
    pub fn emergency_stop(&mut self) {
        self.stopped = true;
    }

    pub fn resume(&mut self) {
        self.stopped = false;
    }

    pub fn grants(&self) -> &[Grant] {
        &self.grants
    }

    pub fn audit_log(&self) -> &[AuditRecord] {
        &self.audit
    }

    pub fn revoke(&mut self, id: u64) -> bool {
        let before = self.grants.len();
        self.grants.retain(|g| g.id != id);
        before != self.grants.len()
    }

    pub fn revoke_all(&mut self) {
        self.grants.clear();
    }

    /// Record a grant created by an explicit user decision.
    /// (Eight parameters is deliberate for now; fold into a `GrantSpec` struct when integrating.)
    #[allow(clippy::too_many_arguments)]
    pub fn grant(
        &mut self,
        component: &str,
        capability: &str,
        access: Access,
        scope: Scope,
        ttl: Option<Duration>,
        one_shot: bool,
        now: SystemTime,
    ) -> Result<u64, String> {
        let scope = match scope {
            Scope::PathPrefix(p) => {
                let canon = resolve(&p)?;
                let normals = canon.components().filter(|c| matches!(c, Component::Normal(_))).count();
                if normals < 2 {
                    return Err("scope too broad (need at least two path components)".into());
                }
                if self.protected.iter().any(|r| canon.starts_with(r) || r.starts_with(&canon)) {
                    return Err("scope overlaps a protected location".into());
                }
                Scope::PathPrefix(canon)
            }
            other => other,
        };
        let id = self.next_id;
        self.next_id += 1;
        self.grants.push(Grant {
            id,
            component: component.to_string(),
            capability: capability.to_string(),
            access,
            scope,
            expires_at: ttl.map(|t| now + t),
            one_shot,
        });
        Ok(id)
    }

    pub fn evaluate(&mut self, req: &Request, now: SystemTime) -> Decision {
        let decision = self.decide(req, now);
        self.log(req, &decision, now);
        decision
    }

    fn decide(&mut self, req: &Request, now: SystemTime) -> Decision {
        if self.stopped {
            return Decision::Deny { reason: "emergency stop active".into() };
        }
        let resolved = match &req.target {
            Target::Path(p) => match resolve(p) {
                Ok(r) => Some(r),
                Err(e) => return Decision::Deny { reason: format!("unsafe path: {e}") },
            },
            _ => None,
        };
        if let Some(r) = &resolved {
            if self.protected.iter().any(|p| r.starts_with(p)) {
                return Decision::Deny { reason: "target is in a protected location".into() };
            }
        }
        self.grants.retain(|g| g.expires_at.is_none_or(|t| t > now));

        let needs_one_shot =
            self.mode == Mode::AskEveryTime || req.risk >= Risk::High || req.access == Access::Delete;
        let found = self
            .grants
            .iter()
            .position(|g| g.matches(req, resolved.as_deref()) && (!needs_one_shot || g.one_shot));
        match found {
            Some(i) => {
                let id = self.grants[i].id;
                if self.grants[i].one_shot {
                    self.grants.remove(i);
                }
                Decision::Allow { grant_id: id }
            }
            None => Decision::Ask { prompt: describe(req, resolved.as_deref()) },
        }
    }

    fn log(&mut self, req: &Request, d: &Decision, now: SystemTime) {
        let outcome = match d {
            Decision::Allow { grant_id } => format!("allow(grant={grant_id})"),
            Decision::Ask { .. } => "ask".to_string(),
            Decision::Deny { reason } => format!("deny({reason})"),
        };
        self.audit.push(AuditRecord {
            unix_secs: now.duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0),
            component: req.component.clone(),
            capability: req.capability.clone(),
            access: req.access,
            target: target_str(&req.target),
            args: redact(&req.args_summary),
            outcome,
        });
    }
}

impl Grant {
    fn matches(&self, req: &Request, resolved: Option<&Path>) -> bool {
        if self.component != req.component || self.capability != req.capability || self.access != req.access {
            return false;
        }
        match (&self.scope, &req.target, resolved) {
            (Scope::PathPrefix(p), Target::Path(_), Some(r)) => r.starts_with(p),
            (Scope::Host(h), Target::Host(t), _) => t.eq_ignore_ascii_case(h),
            (Scope::Exact(s), Target::Other(t), _) => s == t,
            _ => false,
        }
    }
}

/// Resolve to an absolute, symlink-free path. Rejects relative paths, `..` and dangling symlinks.
pub fn resolve(path: &Path) -> Result<PathBuf, String> {
    if !path.is_absolute() {
        return Err("relative path".into());
    }
    if path.components().any(|c| matches!(c, Component::ParentDir)) {
        return Err("parent-directory component".into());
    }
    if let Ok(c) = path.canonicalize() {
        return Ok(c);
    }
    if fs::symlink_metadata(path).map(|m| m.file_type().is_symlink()).unwrap_or(false) {
        return Err("dangling symlink".into());
    }
    let parent = path.parent().ok_or("no parent")?;
    let name = path.file_name().ok_or("no file name")?;
    let parent = parent.canonicalize().map_err(|e| format!("parent not resolvable: {e}"))?;
    Ok(parent.join(name))
}

const SENSITIVE: [&str; 7] = ["key", "token", "password", "passwd", "secret", "auth", "cookie"];

/// Redact obvious secrets (`key=...`, `Bearer ...`) and cap length. Best-effort, not a guarantee.
pub fn redact(s: &str) -> String {
    let mut out: Vec<String> = Vec::new();
    let mut redact_next = false;
    for tok in s.split_whitespace() {
        if redact_next {
            out.push("[REDACTED]".into());
            redact_next = false;
            continue;
        }
        if let Some(eq) = tok.find('=') {
            let key = tok[..eq].to_ascii_lowercase();
            if SENSITIVE.iter().any(|w| key.contains(w)) {
                out.push(format!("{}=[REDACTED]", &tok[..eq]));
                continue;
            }
        }
        if tok.eq_ignore_ascii_case("bearer") {
            redact_next = true;
        }
        out.push(tok.to_string());
    }
    let joined = out.join(" ");
    if joined.chars().count() > 200 {
        joined.chars().take(200).collect::<String>() + "…"
    } else {
        joined
    }
}

fn target_str(t: &Target) -> String {
    match t {
        Target::Path(p) => p.display().to_string(),
        Target::Host(h) => format!("host:{h}"),
        Target::Other(o) => o.clone(),
    }
}

fn describe(req: &Request, resolved: Option<&Path>) -> String {
    let target = match resolved {
        Some(r) => r.display().to_string(),
        None => target_str(&req.target),
    };
    format!(
        "{} wants {:?} ({}) on {} [risk {:?}]: {}",
        req.component,
        req.access,
        req.capability,
        target,
        req.risk,
        redact(&req.args_summary)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let p = std::env::temp_dir().join(format!("hlna-broker-{}-{}", name, std::process::id()));
        let _ = fs::remove_dir_all(&p);
        fs::create_dir_all(&p).unwrap();
        p.canonicalize().unwrap()
    }

    fn req(path: &Path, access: Access, risk: Risk) -> Request {
        Request {
            component: "mcp:fs".into(),
            capability: "fs.op".into(),
            access,
            target: Target::Path(path.to_path_buf()),
            args_summary: "test".into(),
            risk,
        }
    }

    fn now() -> SystemTime {
        SystemTime::now()
    }

    #[test]
    fn no_grant_means_ask() {
        let dir = tmp("ask");
        let mut b = Broker::new(Mode::Policy, vec![]);
        assert!(matches!(b.evaluate(&req(&dir.join("a"), Access::Read, Risk::Low), now()), Decision::Ask { .. }));
    }

    #[test]
    fn grant_allows_inside_and_not_outside() {
        let dir = tmp("scope");
        let inside = dir.join("proj");
        let sibling = dir.join("proj-evil");
        fs::create_dir_all(&inside).unwrap();
        fs::create_dir_all(&sibling).unwrap();
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(inside.clone()), None, false, now()).unwrap();
        assert!(matches!(b.evaluate(&req(&inside.join("f.txt"), Access::Read, Risk::Low), now()), Decision::Allow { .. }));
        // "proj-evil" shares a string prefix with "proj" but is a different directory
        assert!(matches!(b.evaluate(&req(&sibling.join("f.txt"), Access::Read, Risk::Low), now()), Decision::Ask { .. }));
        // read grant must not allow write
        assert!(matches!(b.evaluate(&req(&inside.join("f.txt"), Access::Write, Risk::Low), now()), Decision::Ask { .. }));
    }

    #[test]
    fn other_component_cannot_use_grant() {
        let dir = tmp("comp");
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(dir.clone()), None, false, now()).unwrap();
        let mut r = req(&dir.join("x"), Access::Read, Risk::Low);
        r.component = "plugin:evil".into();
        assert!(matches!(b.evaluate(&r, now()), Decision::Ask { .. }));
    }

    #[cfg(unix)]
    #[test]
    fn symlink_escape_is_not_allowed() {
        let dir = tmp("symlink");
        let granted = dir.join("granted");
        let outside = dir.join("outside");
        fs::create_dir_all(&granted).unwrap();
        fs::create_dir_all(&outside).unwrap();
        fs::write(outside.join("secret.txt"), "x").unwrap();
        std::os::unix::fs::symlink(&outside, granted.join("link")).unwrap();
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(granted.clone()), None, false, now()).unwrap();
        let d = b.evaluate(&req(&granted.join("link/secret.txt"), Access::Read, Risk::Low), now());
        assert!(matches!(d, Decision::Ask { .. }), "symlink escape must not be allowed, got {d:?}");
    }

    #[cfg(unix)]
    #[test]
    fn dangling_symlink_denied() {
        let dir = tmp("dangling");
        std::os::unix::fs::symlink(dir.join("nowhere"), dir.join("dl")).unwrap();
        let mut b = Broker::new(Mode::Policy, vec![]);
        assert!(matches!(b.evaluate(&req(&dir.join("dl"), Access::Write, Risk::Low), now()), Decision::Deny { .. }));
    }

    #[test]
    fn protected_root_denied_even_with_grant_attempt() {
        let dir = tmp("protected");
        let jan = dir.join("jan-profile");
        fs::create_dir_all(&jan).unwrap();
        let mut b = Broker::new(Mode::Policy, vec![jan.clone()]);
        assert!(b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(jan.clone()), None, false, now()).is_err());
        // broader grant containing the protected dir is also refused
        assert!(b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(dir.clone()), None, false, now()).is_err());
        assert!(matches!(b.evaluate(&req(&jan.join("data.db"), Access::Read, Risk::Low), now()), Decision::Deny { .. }));
    }

    #[test]
    fn broad_scopes_rejected() {
        let mut b = Broker::new(Mode::Policy, vec![]);
        assert!(b.grant("c", "x", Access::Read, Scope::PathPrefix("/".into()), None, false, now()).is_err());
        assert!(b.grant("c", "x", Access::Read, Scope::PathPrefix("/tmp".into()), None, false, now()).is_err());
    }

    #[test]
    fn relative_and_parent_paths_denied() {
        let mut b = Broker::new(Mode::Policy, vec![]);
        assert!(matches!(b.evaluate(&req(Path::new("rel/file"), Access::Read, Risk::Low), now()), Decision::Deny { .. }));
        let dir = tmp("dotdot");
        let sneaky = dir.join("a/../b");
        assert!(matches!(b.evaluate(&req(&sneaky, Access::Read, Risk::Low), now()), Decision::Deny { .. }));
    }

    #[test]
    fn grants_expire() {
        let dir = tmp("expiry");
        let t0 = now();
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(dir.clone()), Some(Duration::from_secs(60)), false, t0).unwrap();
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Read, Risk::Low), t0 + Duration::from_secs(30)), Decision::Allow { .. }));
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Read, Risk::Low), t0 + Duration::from_secs(61)), Decision::Ask { .. }));
        assert!(b.grants().is_empty());
    }

    #[test]
    fn one_shot_is_consumed() {
        let dir = tmp("oneshot");
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Write, Scope::PathPrefix(dir.clone()), None, true, now()).unwrap();
        let r = req(&dir.join("f"), Access::Write, Risk::Medium);
        assert!(matches!(b.evaluate(&r, now()), Decision::Allow { .. }));
        assert!(matches!(b.evaluate(&r, now()), Decision::Ask { .. }));
    }

    #[test]
    fn high_risk_and_delete_need_one_shot() {
        let dir = tmp("highrisk");
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Write, Scope::PathPrefix(dir.clone()), None, false, now()).unwrap();
        b.grant("mcp:fs", "fs.op", Access::Delete, Scope::PathPrefix(dir.clone()), None, false, now()).unwrap();
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Write, Risk::High), now()), Decision::Ask { .. }));
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Delete, Risk::Low), now()), Decision::Ask { .. }));
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Write, Risk::Medium), now()), Decision::Allow { .. }));
    }

    #[test]
    fn ask_every_time_ignores_standing_grants() {
        let dir = tmp("askevery");
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(dir.clone()), None, false, now()).unwrap();
        b.set_mode(Mode::AskEveryTime);
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Read, Risk::Low), now()), Decision::Ask { .. }));
    }

    #[test]
    fn emergency_stop_denies_all_then_resume() {
        let dir = tmp("stop");
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(dir.clone()), None, false, now()).unwrap();
        b.emergency_stop();
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Read, Risk::Low), now()), Decision::Deny { .. }));
        b.resume();
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Read, Risk::Low), now()), Decision::Allow { .. }));
    }

    #[test]
    fn revoke_works() {
        let dir = tmp("revoke");
        let mut b = Broker::new(Mode::Policy, vec![]);
        let id = b.grant("mcp:fs", "fs.op", Access::Read, Scope::PathPrefix(dir.clone()), None, false, now()).unwrap();
        assert!(b.revoke(id));
        assert!(!b.revoke(id));
        assert!(matches!(b.evaluate(&req(&dir.join("f"), Access::Read, Risk::Low), now()), Decision::Ask { .. }));
    }

    #[test]
    fn host_and_exact_scopes() {
        let mut b = Broker::new(Mode::Policy, vec![]);
        b.grant("c", "net.get", Access::Network, Scope::Host("127.0.0.1".into()), None, false, now()).unwrap();
        let mk = |h: &str| Request {
            component: "c".into(), capability: "net.get".into(), access: Access::Network,
            target: Target::Host(h.into()), args_summary: String::new(), risk: Risk::Low,
        };
        assert!(matches!(b.evaluate(&mk("127.0.0.1"), now()), Decision::Allow { .. }));
        assert!(matches!(b.evaluate(&mk("evil.example"), now()), Decision::Ask { .. }));
    }

    #[test]
    fn redaction_and_audit_do_not_leak_secrets() {
        assert_eq!(redact("curl --header Authorization: Bearer abc123 x"), "curl --header Authorization: Bearer [REDACTED] x");
        assert_eq!(redact("run api_key=SECRET1 password=hunter2 ok"), "run api_key=[REDACTED] password=[REDACTED] ok");
        let dir = tmp("audit");
        let mut b = Broker::new(Mode::Policy, vec![]);
        let mut r = req(&dir.join("f"), Access::Read, Risk::Low);
        r.args_summary = "token=SUPERSECRET".into();
        let _ = b.evaluate(&r, now());
        let log = b.audit_log();
        assert_eq!(log.len(), 1);
        assert!(!log[0].args.contains("SUPERSECRET"));
        assert_eq!(log[0].component, "mcp:fs");
        let long = "x ".repeat(500);
        assert!(redact(&long).chars().count() <= 201);
    }
}
