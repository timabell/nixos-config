#!/usr/bin/env bash
# Per-process bubblewrap sandbox. Vendored from the NixOS variant in
# https://github.com/timabell/sandbox — that repo documents the threat
# model and why a single risky command (typically an LLM agent) is worth
# isolating from the host. See also security-boundaries.md here.
#
# On NixOS the real binaries live in /nix/store and are exposed via
# /run/current-system/sw/bin (/usr/bin/bash does not exist), so this binds
# the store directly. The nix wrapper (modules/sandbox/default.nix) supplies
# two things via the environment: SANDBOX_BASHRC (the bashrc store path) and
# SANDBOX_EXTRA_PATH (PATH entries to prepend inside the sandbox — the host
# uses it to make claude-code reachable inside without installing it on the
# host PATH).

# HOME is remapped inside the sandbox; tools write here, not to the host home.
SANDBOX_HOME="/home/user"

# Claude Code's mutable state (login, sessions for --resume, config,
# onboarding) is persisted in a dedicated host directory, kept separate from
# any real ~/.claude on the host — which matters on the devvm, where claude
# also runs outside the sandbox. Only the paths it needs are bound in below
# (~/.claude and ~/.claude.json); the rest of the home stays ephemeral.
# ~/.claude.json is pre-created so its bind exists from the first run.
# Override the location with SANDBOX_STATE.
SANDBOX_STATE="${SANDBOX_STATE:-${XDG_DATA_HOME:-$HOME/.local/share}/sandboxed-claude}"
mkdir -p "$SANDBOX_STATE/.claude"
[ -e "$SANDBOX_STATE/.claude.json" ] || printf '{}\n' > "$SANDBOX_STATE/.claude.json"

# Split args: paths, --env-file flags, and extra bwrap args (after "--")
paths=()
env_files=()
extra_args=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--" ]]; then
    shift
    extra_args=("$@")
    break
  elif [[ "$1" == "--env-file" ]]; then
    shift
    [[ -f "${1:-}" ]] || { echo "Error: env file not found: ${1:-}" >&2; exit 1; }
    env_files+=("$1")
    shift
  else
    paths+=("$1")
    shift
  fi
done
# Default to $PWD if no paths given
if [[ ${#paths[@]} -eq 0 ]]; then paths=("$PWD"); fi

# Resolve all paths to absolute
resolved=()
for p in "${paths[@]}"; do
  resolved+=("$(readlink -f "$p")")
done

args=(
  --ro-bind /nix/store /nix/store       # all NixOS binaries + libraries live here
  --ro-bind /run/current-system /run/current-system  # PATH points at sw/bin
  --ro-bind /usr /usr                   # /usr/bin/env symlink (used by shebangs)
  --ro-bind /bin /bin                   # /bin/sh symlink
  --ro-bind /lib64 /lib64               # nix-ld dynamic linker shim
  --proc /proc                          # process info, needed by node/dotnet
  --dev /dev                            # /dev/null, /dev/urandom, etc.
  --tmpfs /tmp                          # isolated ephemeral tmp (not host's)

  # DNS resolution + TLS for outbound HTTPS (Claude API, registries)
  --ro-bind /etc/resolv.conf /etc/resolv.conf
  --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf
  --ro-bind /etc/hosts /etc/hosts
  --ro-bind /etc/ssl /etc/ssl           # TLS certificates
  --ro-bind /etc/static /etc/static     # /etc/ssl/certs/* symlinks resolve through here
  --ro-bind /etc/passwd /etc/passwd     # user name resolution (needed by `claude --resume`)

  # Claude Code state, persisted on the host (see SANDBOX_STATE above)
  --bind "$SANDBOX_STATE/.claude" "$SANDBOX_HOME/.claude"
  --bind "$SANDBOX_STATE/.claude.json" "$SANDBOX_HOME/.claude.json"

  # shell profile (store path supplied by the nix wrapper)
  --ro-bind "$SANDBOX_BASHRC" "$SANDBOX_HOME/.bashrc"

  --unshare-pid                         # own PID namespace so /proc doesn't leak host processes
  # --new-session not needed: TIOCSTI injection blocked by kernel ≥6.2 (LEGACY_TIOCSTI=n)

  --clearenv                            # wipe host env; only explicitly set vars are visible
  --setenv HOME "$SANDBOX_HOME"         # remap HOME so tools write to sandbox
  --setenv USER "user"
  --setenv TERM "${TERM:-xterm-256color}"
  # SANDBOX_EXTRA_PATH (e.g. claude-code's bin) prepended so it wins over the host PATH
  --setenv PATH "${SANDBOX_EXTRA_PATH:+$SANDBOX_EXTRA_PATH:}/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin"
)

# Mount working directories and set SANDBOX_OUTER_PWD
if [[ ${#resolved[@]} -eq 1 ]]; then
  # Single path: mount directly at ~/work
  args+=(
    --bind "${resolved[0]}" "$SANDBOX_HOME/work"
    --setenv SANDBOX_OUTER_PWD "${resolved[0]}"
  )
else
  # Multiple paths: mount each at ~/work/<basename> over a tmpfs
  args+=(--tmpfs "$SANDBOX_HOME/work")
  outer_list=""
  for p in "${resolved[@]}"; do
    name="$(basename "$p")"
    args+=(--bind "$p" "$SANDBOX_HOME/work/$name")
    outer_list+="${outer_list:+:}$p"
  done
  args+=(--setenv SANDBOX_OUTER_PWD "$outer_list")
fi

# Load .env files into --setenv args (handles spaces and quotes correctly)
for env_file in "${env_files[@]}"; do
  while IFS='=' read -r key value; do
    [[ -n "$key" && "$key" != \#* ]] || continue
    value="${value#\"}" ; value="${value%\"}"
    value="${value#\'}" ; value="${value%\'}"
    args+=(--setenv "$key" "$value")
  done < "$env_file"
done

# Append any extra bwrap args passed after "--"
args+=("${extra_args[@]}")

args+=(--chdir "$SANDBOX_HOME/work")    # start in the working directory

bwrap "${args[@]}" -- /run/current-system/sw/bin/bash
