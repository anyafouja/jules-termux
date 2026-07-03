# Jules CLI on Termux (Android)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Run [Jules](https://jules.google) — Google's autonomous AI coding agent — **natively on Android** via Termux.

## Why This Exists

`@google/jules` is officially distributed as a **Go binary** for Linux/macOS/Windows only. Android is not supported because:

1. **npm platform block** — `npm install -g @google/jules` fails with `Unsupported platform: android`
2. **SIGSYS crash** — The Go binary uses `faccessat2` syscall (439 on arm64), blocked by Android's seccomp filter
3. **No DNS** — Android doesn't have `/etc/resolv.conf`, so Go's DNS resolver falls back to `[::1]:53` and fails
4. **No CA certs at standard paths** — Go expects `/etc/ssl/certs/ca-certificates.crt`

This repo fixes **all four problems** with a lightweight solution using `proot` (336KB) — no full Linux distro needed.

## Quick Install

```bash
pkg install git curl -y
git clone https://github.com/anyafouja/jules-termux
cd jules-termux
chmod +x install.sh && ./install.sh
```

Or one-liner:

```bash
pkg install git curl -y && git clone https://github.com/anyafouja/jules-termux && cd jules-termux && chmod +x install.sh && ./install.sh
```

## Usage

```bash
# Show help
jules --help

# Login with your Google account
jules login

# Create a session for your repo
jules new "add dark mode to settings page"

# Create a session for a specific repo
jules new --repo user/repo "write unit tests"

# Run 3 parallel sessions for the same task
jules new --parallel 3 "fix the login race condition"

# List sessions
jules remote list --session

# Pull session results (and apply patch)
jules remote pull --session <id> --apply

# Teleport: clone repo + checkout branch + apply patch
jules teleport <session_id>
```

## How It Works

```
┌──────────────────────────────────────────────────┐
│  jules (wrapper script)                          │
│  /data/data/com.termux/files/usr/bin/jules       │
│                                                  │
│  Uses proot to:                                  │
│  ├─ Translate blocked syscalls (faccessat2)      │
│  ├─ Bind /etc/resolv.conf (DNS)                  │
│  └─ Bind /etc/ssl/certs (TLS)                    │
│          │                                       │
│          ▼                                       │
│  jules binary (20MB Go binary)                   │
│  ~/.jules/jules                                  │
└──────────────────────────────────────────────────┘
```

### Why proot (not proot-distro)?

| Approach | Size | Description |
|----------|------|-------------|
| **proot** (this repo) | **336KB** | Ptrace syscall translator only |
| proot-distro | 500MB+ | Downloads full Linux distro image |

We use `proot` stand-alone — just the syscall translation layer. No Ubuntu/Debian container needed.

## Prerequisites

- **Termux** from [F-Droid](https://f-droid.org/en/packages/com.termux/) (recommended) or GitHub
- **~500MB free storage** (20MB binary + minimal overhead)
- **Google account** (for Jules authentication)

## Troubleshooting

### `jules version` hangs after showing version info

This is the **self-update check** timing out (TLS within proot is rate-limited). Core commands (`new`, `remote`, `login`, `help`) work instantly.

```bash
timeout 5 jules version    # Just grab the version info
```

### `SIGSYS: bad system call`

You're running the binary **without proot**. Always use the `jules` wrapper.

```bash
# ✅ Correct
jules --help

# ❌ Wrong — will crash
~/.jules/jules --help
```

### `npm install -g @google/jules` fails

The npm package has a platform check that blocks Android. Use the installer from this repo instead.

## Files

| File | Purpose |
|------|---------|
| `install.sh` | One-command installer |
| `README.md` | This file |
| `LICENSE` | MIT license |

## License

MIT
