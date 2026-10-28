#!/bin/sh
# install.sh - PS5 LLM Alpine Distro installer
# Run on a fresh Alpine Linux edge installation (x86_64)
#
# Usage: sh scripts/install.sh   (from the repo root)
#
# This script:
#   1. Installs all required packages (1:1 from the reference device)
#   2. Builds llama.cpp with Vulkan + RPC
#   3. Installs PS5 LLM TUI, CLI, HF tools
#   4. Configures OpenRC init scripts
#   5. Creates clean directory structure (no personal data)

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== PS5 LLM Alpine Distro Installer ==="
echo "Repo: $REPO_ROOT"
echo ""

# ---------- 1. Packages ----------
echo "[1/6] Installing packages..."
apk update

# Install from the reference package list (1:1 with working device)
# Filter out world/lock entries and install the rest
grep -v '^world$\|^lock$\|^installed$\|^local$' "$REPO_ROOT/packages.txt" | \
    xargs apk add --no-cache 2>&1 | tail -5

echo "  Packages installed."

# ---------- 2. llama.cpp ----------
echo "[2/6] Building llama.cpp (Vulkan + RPC)..."
LLAMA_DIR=/opt/llama.cpp

if [ -x "$LLAMA_DIR/llama-server" ]; then
    echo "  llama.cpp already present - skipping build."
else
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /tmp/llama.cpp
    cmake -S /tmp/llama.cpp -B /tmp/llama.cpp/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN=ON \
        -DGGML_RPC=ON \
        -DCMAKE_INSTALL_PREFIX="$LLAMA_DIR" \
        -DBUILD_SHARED_LIBS=ON
    cmake --build /tmp/llama.cpp/build -j"$(nproc)"
    cmake --install /tmp/llama.cpp/build
    rm -rf /tmp/llama.cpp
    echo "  llama.cpp built and installed to $LLAMA_DIR"
fi

# ---------- 3. PS5 LLM tools ----------
echo "[3/6] Installing PS5 LLM tools..."

# Main binaries
install -m 755 "$REPO_ROOT/bin/ps5llm-tui"       /usr/bin/ps5llm-tui
install -m 755 "$REPO_ROOT/bin/ps5llm"           /usr/bin/ps5llm
install -m 755 "$REPO_ROOT/bin/ps5llm-console"   /usr/bin/ps5llm-console

# Local utilities
install -m 755 "$REPO_ROOT/bin/ps5llm-hf"        /usr/local/bin/ps5llm-hf
install -m 755 "$REPO_ROOT/bin/ram-valve.sh"     /usr/local/bin/ram-valve.sh
install -m 755 "$REPO_ROOT/bin/wifi-watchdog.sh" /usr/local/bin/wifi-watchdog.sh

# TUI menu (sourced at runtime)
mkdir -p /usr/local/lib
install -m 644 "$REPO_ROOT/lib/menu_hf.sh"       /usr/local/lib/menu_hf.sh

echo "  Tools installed."

# ---------- 4. Init scripts ----------
echo "[4/6] Configuring OpenRC services..."

install -m 755 "$REPO_ROOT/init.d/llama-server"       /etc/init.d/llama-server
install -m 755 "$REPO_ROOT/init.d/wpa_cli"            /etc/init.d/wpa_cli
install -m 755 "$REPO_ROOT/init.d/wpa_supplicant"     /etc/init.d/wpa_supplicant
[ -f "$REPO_ROOT/init.d/ps5-stage-firmware" ] && \
    install -m 755 "$REPO_ROOT/init.d/ps5-stage-firmware" /etc/init.d/ps5-stage-firmware

rc-update add llama-server default
rc-update add wpa_cli default
rc-update add wpa_supplicant default
rc-update add sshd default
rc-update add syslog-ng default
rc-update add chronyd default
rc-update add crond default

# Boot-time WiFi restore (associate + DHCP). The wpa_supplicant service only
# associates; without this nothing runs a DHCP client after boot.
mkdir -p /etc/local.d
install -m 755 "$REPO_ROOT/etc/wifi-restore.start" /etc/local.d/wifi-restore.start
rc-update add local default 2>/dev/null || true

echo "  Services configured."

# ---------- 5. Directory structure + clean configs ----------
echo "[5/6] Creating directories and clean configs..."

mkdir -p /models
mkdir -p /var/lib/ps5llm-hf/jobs
mkdir -p /var/lib/ps5llm-hf/cache
mkdir -p /etc/llama
mkdir -p /etc/wpa_supplicant
mkdir -p /var/log

# Clean LLM config (no model set, no personal IPs)
install -m 644 "$REPO_ROOT/etc/llama.conf" /etc/llama/llama.conf

# Clean WiFi config (no networks)
install -m 600 "$REPO_ROOT/etc/wpa_supplicant.conf" /etc/wpa_supplicant/wpa_supplicant.conf

# Empty model inventory
printf 'repo_id\trevision\tpath\tsize\tstatus\tquant\tformat\n' > /var/lib/ps5llm-hf/inventory.tsv

echo "  Directories and configs ready."

# ---------- 6. Final setup ----------
echo "[6/6] Final setup..."

# Generic hostname (user can change)
echo "ps5llm" > /etc/hostname

# Ensure networking is enabled
rc-update add networking default 2>/dev/null || true

# WiFi watchdog cron (every 2 min)
mkdir -p /etc/periodic/15min
cat > /etc/periodic/15min/wifi-watchdog << 'CRONEOF'
#!/bin/sh
/usr/local/bin/wifi-watchdog.sh
CRONEOF
chmod +x /etc/periodic/15min/wifi-watchdog

echo ""
echo "=========================================="
echo "  Installation complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Connect WiFi:     ps5llm wifi scan"
echo "                     ps5llm wifi connect <SSID>"
echo "  2. Download a model: ps5llm-tui"
echo "     (Huggingface Models -> Browse -> pick -> Download)"
echo "  3. Set the model:    ps5llm model set /models/<your-model>.gguf"
echo "  4. Start server:     rc-service llama-server start"
echo ""
echo "Fresh slate - no personal data was installed."
echo ""
