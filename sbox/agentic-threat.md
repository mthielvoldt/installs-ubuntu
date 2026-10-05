## 1. The threat model that changed

The old rule — *"keep secrets out of git and you're fine"* — assumed the only adversary
was an accidental commit. **Agentic coding breaks that assumption.** An AI agent (or any
tool/MCP/dependency it invokes) running with **code-execution as your OS user** can read
anything that user can read: `.env`, `~/.ssh`, cloud-CLI creds, browser cookies, shell
history, and the environment of *other processes the same user owns* (`/proc/<pid>/environ`
on Linux). `.gitignore` does nothing against this; it only stops commits.

For a contractor holding **clients'** secrets, the blast radius (e.g. a leaked Supabase
service-role key = full DB, RLS bypassed) makes this worth real mitigation — not paranoia.

**Core principle:** confidentiality from a *same-UID* attacker requires a **privilege
boundary** (a different user, a sandbox, or the secret simply not being on the box), **not**
a file mode. `chmod 600` only gates *other* users; it does nothing against a process
running as you.

---
## 2. What we verified about the *current* setup (2026-06-09)

The coding agent here runs in a sandbox. We probed its real boundary (don't assume — it
can change; re-verify with the methods noted if mounts change):

- **Filesystem = an explicit bind-mount allowlist**, not repo-scoped and not all-of-home.
  Readable host content was limited to the mounted paths: `repos/swerv` (whole repo, incl.
  `.env`), `~/.claude` + `~/.claude.json`, `~/.bashrc`, `~/.espressif`, `~/.local/{bin,share/claude}`,
  `~/.npm/_logs`, `~/.nvm/.../<node>`, `~/installs/{aliases.sh,sbox/inner.sh}`, plus a minimal
  system base. **Not visible:** `/etc/passwd`, `/root`, other repos (`~/repos` showed only
  `swerv`), and host `~/.config` / `~/.cache` / `~/.ssh` / `~/.aws` (those aren't mounted, so
  only a base-image stub shows).
  - *Verify a candidate secret location is outside reach:* put a marker file there and have
    the agent `cat` it. "No such file" = outside the mount set = safe from the agent.
- **PID namespace is isolated.** A live host process (tested: pid 3723) was invisible
  (`/proc/3723` → No such file); visible PIDs were the sandbox's own. **So the
  `/proc/<pid>/environ` exfiltration path is closed from inside this sandbox** — unlike an
  *unsandboxed* same-user agent, where it is wide open.
- **Method:** `cat /proc/self/mountinfo`, `ls /proc | grep '^[0-9]'`, spot reads.

**Residual exposure even in this sandbox:** `~/.claude` + `~/.claude.json` are mounted and
readable, so the agent can read its own account/auth material; and the entire `supa/` tree
(including `.env`) is readable. Today that `.env` holds only the **well-known local Supabase
demo keys** (public by design) and one real secret — a **dev** Google OAuth client secret —
so current real exposure is low. The discipline matters because the same file becomes the
home of prod keys later.

> **Immediate, cheap hygiene:** the dev `GOOGLE_CLIENT_SECRET` has passed through agent
> context/transcripts this project. Rotating that dev OAuth client secret costs nothing and
> is a good first rep of a rotation habit. ☐

---