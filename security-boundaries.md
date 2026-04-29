# Host security boundaries

**Status:** draft.
**Scope:** which workloads run on the host, which in a VM, which in a per-process
sandbox; what crosses each boundary.
**Audience:** future-me, plus anyone evaluating whether this setup is sane.

Decisions are tagged **Decided** (committed, hard rule), **Current** (working
assumption, change later if needed), or **Open** (not resolved; needs a real
trial before locking in).

## Threat model

**In scope:**

- Supply-chain attacks via language package managers: npm, nuget, cargo,
  pip, gem, go modules. Malicious postinstall scripts, transitively
  pulled compromised packages, typo-squatted deps. Too common & serious to
  ignore these days
- Compromised dev tooling: IDE extensions (VS Code marketplace, JetBrains
  plugins), MCP servers, LSPs, formatters that run in-editor.
- Rogue / curious LLM agents (Claude, Cursor, etc.) reading more than
  they should, or executing commands beyond their stated remit. This
  *includes* deliberately running agents in permission-bypass mode for
  speed (see "Rapid LLM iteration").

**Out of scope** (or accepted risk):

- Targeted attackers, nation-state, custom malware.
- Hardware/firmware/SMM attacks.
- VM & sandbox escape capabilities.
- Physical access.
- Browser zero-days delivering remote code execution.
- The user's own keyboard.

## Layers (most → least trusted)

### 1. Host (the laptop/desktop)

Full trust. Holds the user identity:

- GPG signing key (commits, releases)
- Long-lived SSH keys (GitHub `git push`, server access)
- Browser sessions, OAuth tokens
- Password manager
- Email, calendar, chat (Slack, Signal)
- Source code

Compromise here = total. Defence is mostly "don't put untrusted code
here". Run risky stuff in lower layers.

### 2. devvm (per-context dev environment)

Semi-trusted. Boundary against supply-chain attacks during normal dev
work:

- Cloning client repos
- `npm install` / `dotnet restore` / `cargo build` / etc.
- Running tests, build pipelines, debuggers
- Editing in Rider / VS Code
- Running services locally (containers, dev databases)
- Running LLM agents — including in permission-bypass modes

**Acceptable blast radius:** VM is toast. We rebuild it. The attacker
gets:

- Whatever code is checked out inside it
- Whatever short-lived tokens we let in
- Network access (outbound) for the duration

**Unacceptable blast radius:** anything that crosses back to the host —
host filesystem access, host SSH keys, GPG signing key, browser session,
ability to push poisoned commits as the user.

### 3. Bubblewrap sandbox (per-process)

Least trusted. For a single risky command — typically an LLM agent or a
one-off script — bound into a tight bwrap with minimal binds, no host
network or scoped network, no broad filesystem access.

See [timabell/sandbox](https://github.com/timabell/sandbox).

Compromise here = whatever was bound in. A few cache directories, the
specific working tree mounted in. Not the whole VM, not the host.

bwrap is great for headless commands but doesn't easily handle GUI/web
workloads (no display server, no browser, no IDE). For those, the VM is
the boundary.

## Asset inventory

| Asset | Lives on | Visible to VM? | Visible to bwrap? |
|---|---|---|---|
| GPG signing key | Host | **No** | No |
| SSH key for `git push` (GitHub) | Host | **No** (see Open) | No |
| SSH keys for client servers | Host | No | No |
| Cloud credentials (long-lived) | Host | No | No |
| Cloud credentials (short-lived / scoped) | VM | Yes | Maybe |
| Source code (cloned for dev) | VM | Yes | Bound subdir only |
| Source code (host backup) | Host | No | No |
| Browser sessions, OAuth | Host | No | No |
| Password manager DB | Host | No | No |
| Dotfiles (subset) | Both | Yes (slim version) | Read-only bind |

## Decisions and tensions

### Git commit signing

**Status:** current.

GPG key only on the host. Commits made inside the VM are unsigned
(already configured). Workflow options:

- **(A) Don't sign commits during dev.** Sign only tags/releases, on
  host. Most pragmatic; matches what most repos accept. Loses per-commit
  signature trail.
- **(B) VM commits unsigned to a topic branch; host re-commits or
  squashes with signature before pushing upstream.** Preserves signing
  on the upstream tip. Adds a step. Right for client work where signed
  history matters.
- **(C) Separate signing subkey in the VM, easily revocable.** Sign in
  VM directly. Compromise = attacker signs as you until you notice.
  Don't love it.

**Current: (A) day-to-day, (B) for repos that enforce signing.**

### SSH key for `git push`

**Status:** open.

If the VM holds the key, attacker can push poisoned commits as you to
any repo you have write access to. Subtle and durable.

If the host holds the key, the VM can `clone` over HTTPS but can't
`push` — meaning either you push from the host (so code has to leave
the VM somehow) or you give the VM something with push access (PAT,
deploy key, …).

Options:

- **(A) Read-only access in VM** (HTTPS clone, no push). Push happens
  from host after reviewing what came back. Code crosses host↔VM via
  virtiofs or `scp` over the libvirt NAT.
- **(B) Per-repo deploy keys in VM** with push access scoped to one
  repo. Compromise of VM ≠ compromise of all your repos. More setup.
- **(C) Short-lived PAT scoped to one repo** stored in VM. Easily
  rotated; if leaked, blast radius is one repo for ≤ N days. Mid effort.
- **(D) Long-lived SSH key in VM.** The full-blast option. Don't.

**Current: (A) with (B) or (C) as the bridge for repos where pushing from
the host is annoying.** Resolution requires a real workflow trial.

### SSH agent forwarding

**Status:** decided.

Forwarding the host's SSH agent into the VM lets the VM authenticate as
you to anything your host can reach (GitHub, servers). Convenient,
catastrophic if VM is compromised — every server you've ever sshed
into is reachable while the agent is forwarded.

**Decision: never forward the host SSH agent into the VM.** If the VM
needs server access, it gets its own scoped key.

### File sharing (virtiofs)

**Status:** decided (rules); open (RO default).

The convenient direction is "mount `~/work/client-foo` from host into
VM". The risk is binding too much:

- Mounting `~/` would expose `.ssh`, `.gnupg`, browser data, password
  store. Catastrophic.
- Mounting `~/work` exposes all clients' code to a compromised VM,
  which violates per-client isolation.
- Mounting `~/work/client-foo` is the right scope: exposes only the
  current engagement.

**Rules:**

- Never mount anything containing host secrets.
- Mount narrowly (one client / one project at a time).
- The mount is configured per-VM-invocation, not baked into the
  NixOS config. Already done — `dev-vm-install.sh` is where it lives.

**Open:** whether the share should be read-only by default. Convenient
to have writes back to the host (committing from host etc.), but it
re-opens an exfil path.

### SPICE clipboard

**Status:** current.

Bidirectional copy/paste between host and VM. Convenient.

Risks:

- VM reads anything on the host clipboard — including a password just
  copied from the password manager for some other window.
- VM writes the host clipboard — feeds the user a poisoned command they
  paste into a host shell.

**Current: keep clipboard enabled** because the friction of disabling it
is high. **Mitigation:** discipline — don't copy host secrets while a
VM is running. Treat the host clipboard as VM-readable for the
duration.

### Rapid LLM iteration (permission-bypass agents)

**Status:** decided (the why); open (operational details).

Running an LLM agent in `--dangerously-skip-permissions` mode (Claude
Code) — or "ralph loop" / unattended autonomous loop variants — is
increasingly the right tool for *some* tasks: GUI iteration, web app
exploration, fast prototype loops. The agent self-drives shell + file
edits + browser without confirming each action.

This is not paranoid; it's current best practice for those task shapes.
But the agent must be wrapped in a real isolation boundary, because
"dangerously skip" means exactly what it says.

**Decision:** permission-bypass agent runs happen **only inside the
VM**, never on the host. The VM is the trust boundary. The same VM
holds the working code and tokens; the agent's blast radius is the VM.

**Why this rules out bwrap-only:** bwrap can't host XFCE+browser+IDE
with the kind of fluent display + clipboard + tab access an agentic GUI
loop expects. The VM has all of that natively.

**Why this rules out host-only:** dangerously-skip on the host can
read/edit any file the user can — `.ssh`, `.gnupg`, browser storage,
password manager files, etc. There's no point in any other boundary if
this is allowed.

**Open:**

- One VM per client OR one "messy LLM" VM separate from "client work"
  VMs? An agent run during exploration might pollute the project's
  git tree; might be worth keeping a throwaway VM for that.
- Whether to checkpoint/snapshot the VM before kicking off a
  long-running agent loop, so we can revert.

### Per-VM granularity (clients vs FOSS vs scratch)

**Status:** current.

One VM = supply chain attack on client A's `npm install` can read
client B's code that's also checked out in the same VM.
Cross-contamination across engagements; commercial-confidentiality
problem, not just a personal one.

**Current:**

- **One VM per client.** Each engagement gets its own VM. Names like
  `devvm-acme`, `devvm-globex`. Disposable; rebuild via the bare-image
  + switch flow.
- **One shared FOSS VM** for all open-source / personal projects. The
  isolation properties matter less when everything is already public,
  and the build cache reuse is real.
- **Optionally one scratch / agent VM** for permission-bypass LLM runs
  that aren't tied to a specific client (see above).

The flake config supports this with parameterisation (hostname, share
tag, maybe per-VM allowed-unfree list) — currently not implemented but
straightforward.

**Trip-wire:** if two clients' source ever ends up checked out in the
same VM at the same time, the per-client boundary is broken. Don't.

### Cloud / API tokens

**Status:** decided (principles); open (specifics).

For dev work the VM needs *some* tokens. Principles:

- Scope as narrowly as possible (one project, one repo).
- Short-lived where the provider supports it (GitHub fine-grained PATs
  with expiry, AWS STS, etc.).
- Production deploys never run from the VM — host only, or CI.

**Open:** what specific tokens we expect to live in each VM
steady-state, and what the rotation cadence is.

### MCP servers / LLM agents inside the VM

**Status:** decided.

LLM agents pulling MCP tools or running tool-use loops inside the VM
inherit the VM's blast radius. They can do anything an attacker who
pwned the VM could do. Bwrap-wrap them inside the VM if scope warrants
— same pattern as on host, just nested.

For permission-bypass runs see the dedicated section above.

### Docker / containers for client work

**Status:** decided.

Client Docker workloads — `docker compose up`, building images from a
local Dockerfile, running tests in containers — happen inside the VM.
The host never runs client containers.

Reasoning: containers built from a Dockerfile will pull prebuilt base
layers from registries (Docker Hub etc.) plus run whatever the
Dockerfile + entrypoint say to run. Malicious docker images aren't a
prominent threat right now, but neither are they zero-risk, and there's
no upside to running them on the host. The VM is the right boundary for
all "execute code from this client's repo" surface, including its
container builds.

Practical notes:

- **Container "isolation" inside the VM is defence-in-depth, not a
  security boundary.** Once code is inside the VM, a container escape
  just changes which in-VM directory the attacker can read. That's a
  VM-blast-radius problem, not a host one.
- **Don't mount host paths into containers** via virtiofs pass-through
  (host → VM → container bind). That re-opens the host boundary. Mount
  only in-VM paths.
- **Performance:** containers use Linux namespaces, not nested KVM, so
  cost is just the outer VM overhead. With virtio + host-passthrough
  CPU it's close to bare metal for build/run.
- **Subnet collision watch:** Docker default `172.17.0.0/16` doesn't
  collide with libvirt's default NAT `192.168.122.0/24`, but a client's
  compose file picking something exotic could.

## Crossings (what's allowed across each boundary)

### Host ↔ VM

| Direction | Allowed | Notes |
|---|---|---|
| Host → VM filesystem | Narrow virtiofs (one client dir) | opt-in, per-VM |
| VM → Host filesystem | Same virtiofs share, RW | open: should this be RO by default? |
| Host → VM network | SSH (host → VM) for paste | OK |
| VM → Host network | None unless we expose host services | default no |
| Clipboard | Bidirectional via SPICE | accepted risk |
| SSH agent | **Never forwarded** | hard rule |
| GPG agent | **Never forwarded** | hard rule |

### VM ↔ Internet

| Direction | Allowed | Notes |
|---|---|---|
| VM → Internet | Yes (npm, cache.nixos.org, GitHub HTTPS) | unavoidable |
| Internet → VM | No | firewall default-deny inbound (verify) |

### Bwrap (inside VM or on host)

| Direction | Allowed | Notes |
|---|---|---|
| Filesystem | One bound directory, RO where possible | per invocation |
| Network | Scoped or none | depends on command |

## Hard rules (committed)

- **No GPG keys in the VM.** Done.
- **No long-lived SSH keys in the VM.** Pending verification — add a
  note to `dev-vm.md`.
- **Never forward host SSH/GPG agent into the VM.**
- **virtiofs share is opt-in and narrow.** Done.
- **VM firewall default-deny inbound.** Should already be true via
  `networking.firewall.enable = true`; verify.
- **Don't run two clients in one VM.** Discipline rule.
- **Permission-bypass LLM agents only inside a VM, never on the host.**
- **Production deploys from host or CI, not from a VM.**

## Open questions to resolve next

1. **Push workflow** when host has the key but VM has the work. Pick
   from (A)/(B)/(C) in the SSH key section after a real trial.
2. **virtiofs share read-only by default** or remain RW for convenience?
3. **Per-VM templating in the flake** — implement now, or wait until
   the second engagement triggers it?
4. **Token inventory and rotation cadence** per VM. What lives where,
   for how long?
5. **Snapshot strategy** for permission-bypass agent runs — pre-snap,
   run, evaluate, revert if needed?
