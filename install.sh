#!/data/data/com.termux/files/usr/bin/bash
# Jules CLI Termux Installer
# Direct binary installation + proot for syscall compatibility
# No proot-distro needed — hanya proot stand-alone (336KB)

set -e

# ─── Colors ─────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC} $1"; }

# ─── Config ─────────────────────────────────────────
JULES_VERSION="v0.1.42"
JULES_BIN="/data/data/com.termux/files/usr/bin/jules"
JULES_REAL="/data/data/com.termux/files/home/.jules/jules"
JULES_HOME="/data/data/com.termux/files/home/.jules"

# ─── Detect Architecture ────────────────────────────
ARCH=$(uname -m)
case "$ARCH" in
    aarch64) GOARCH="arm64" ;;
    x86_64)  GOARCH="amd64" ;;
    *)
        err "Unsupported architecture: $ARCH (only aarch64/arm64 and x86_64/amd64)"
        exit 1
        ;;
esac
info "Detected: $ARCH ($GOARCH)"

# ─── Install Dependencies ───────────────────────────
info "Installing dependencies..."
pkg update -y
pkg install -y curl proot
ok "Dependencies installed"

# ─── Download Binary ────────────────────────────────
BINARY_URL="https://storage.googleapis.com/jules-cli/${JULES_VERSION}/jules_external_${JULES_VERSION}_linux_${GOARCH}.tar.gz"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

info "Downloading Jules CLI ${JULES_VERSION}..."
curl -L "$BINARY_URL" -o "$TMP_DIR/jules.tar.gz"
tar -xzf "$TMP_DIR/jules.tar.gz" -C "$TMP_DIR"
ok "Downloaded binary (20MB)"

# ─── Setup Jules Home ───────────────────────────────
mkdir -p "$JULES_HOME"
JULES_BINARY="$JULES_HOME/jules"
rm -f "$JULES_BINARY"
mv "$TMP_DIR/jules" "$JULES_BINARY"
chmod +x "$JULES_BINARY"
ok "Binary installed to $JULES_BINARY"

# ─── Setup DNS (resolv.conf) ────────────────────────
RESOLV_CONF="$JULES_HOME/resolv.conf"
cat > "$RESOLV_CONF" << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
ok "DNS config created"

# ─── Setup CA Certificates ──────────────────────────
# Termux CA bundle — bind to /etc/ssl/certs so Go finds it natively
CA_SRC="/data/data/com.termux/files/usr/etc/tls/cert.pem"
CA_DST="$JULES_HOME/ca-certificates.crt"
if [ -f "$CA_SRC" ]; then
    cp "$CA_SRC" "$CA_DST"
    ok "CA certificates copied"
else
    warn "CA cert file not found at $CA_SRC — TLS may fail"
fi

# ─── Create Proot Wrapper ───────────────────────────
info "Creating wrapper script..."
cat > "$JULES_BIN" << WRAPPER
#!/data/data/com.termux/files/usr/bin/bash
# Jules CLI wrapper for Termux
# Uses proot for syscall translation (faccessat2 etc.)

JULES_BINARY="$JULES_BINARY"
JULES_HOME="$JULES_HOME"
RESOLV_CONF="$JULES_HOME/resolv.conf"
CA_CERTS="$JULES_HOME/ca-certificates.crt"
FAKE_ETC_SSL="\$JULES_HOME/etc/ssl/certs"

# Create minimal /etc/ssl/certs with CA bundle
mkdir -p "\$FAKE_ETC_SSL"
[ -f "\$CA_CERTS" ] && cp "\$CA_CERTS" "\$FAKE_ETC_SSL/ca-certificates.crt"

exec proot \\
    -b "\$RESOLV_CONF:/etc/resolv.conf" \\
    -b "\$FAKE_ETC_SSL:/etc/ssl/certs" \\
    "\$JULES_BINARY" "\$@"
WRAPPER
chmod +x "$JULES_BIN"
ok "Wrapper created at $JULES_BIN"

# ─── Cleanup ────────────────────────────────────────
rm -f /data/data/com.termux/files/usr/bin/jules-android 2>/dev/null

# ─── Verify ─────────────────────────────────────────
info "Verifying installation..."
if command -v jules &>/dev/null; then
    ok "jules command is in PATH: $(command -v jules)"
else
    warn "jules not found in PATH — try restarting Termux or run: hash -r"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Jules CLI Termux Installer Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}jules --help${NC}        Show help"
echo -e "  ${CYAN}jules version${NC}       Show version"
echo -e "  ${CYAN}jules login${NC}         Login Google account"
echo -e "  ${CYAN}jules new \"task\"${NC}    Create session"
echo ""
echo -e "  ${YELLOW}Note:${NC} 'jules version' may hang on self-update"
echo -e "  (background check) — use timeout 5 jules version"
echo ""
