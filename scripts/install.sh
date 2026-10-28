#!/bin/sh
# install.sh - PS5 LLM Alpine Distro installer
# Run on a fresh Alpine Linux edge installation (x86_64)
#
# Usage: sh install.sh
#
# This script:
#   1. Installs required packages
#   2. Sets up llama.cpp (Vulkan/GPU)
#   3. Installs PS5 LLM TUI + CLI + HF tools
#   4. Configures init scripts
#   5. Creates directory structure
#
# Prerequisites:
#   - Fresh Alpine Linux edge (x86_64)
#   - AMD GPU with amdgpu kernel module loaded (for Vulkan)
#   - Network access for package downloads

set -eu

echo "=== PS5 LLM Alpine Distro Installer ==="
echo ""

# ---------- 1. Packages ----------
echo "[1/6] Installing packages..."
apk update
apk add --no-cache \
    linux-headers \
    linux \
    build-base \
    cmake \
    git \
    python3 \
    py3-pip \
    curl \
    wget \
    ca-certificates \
    openrc \
    openrc-run \
    syslog-ng \
    sshd \
    wpa_supplicant \
    wireless-tools \
    util-linux \
    e2fsprogs \
    hwdata \
    kmod \
    pciutils \
    mesa \
    vulkan-radeon-driver \
    vulkan-tools \
    radv \
    s6 \
    s6-rc \
    supervisor \
    rsync \
    rsyncd \
    smartmontools \
    chrtools \
    haveged \
    rng-tools \
    dbus \
    elogind \
    polkit \
    seatd \
    acpid \
    crond \
    ntp \
    chrony \
    rsync \
    openssh \
    linux-efi-alpine \
    mtools \
    dosfstools \
    e2fsprogs-libs \
    libelf \
    libxml2 \
    libxslt \
    sqlite-libs \
    openssl \
    libcurl \
    zlib \
    libffi \
    ncurses-libs \
    readline \
    busybox-extras \
    inotify-tools \
    jq \
    awk \
    sed \
    grep \
    findutils \
    less \
    vi \
    nano \
    htop \
    iostat \
    sysstat \
    lm_sensors \
    fancontrol \
    acpi \
    cpupower \
    turbostat \
    pciutils \
    lshw \
    hdparm \
    smartmontools \
    nvme-cli \
    ata \
    scsi \
    iscsi-initiator-utils \
    multipath-tools \
    lvm2 \
    mdadm \
    cryptsetup \
    device-mapper \
    fuse \
    fuse-overlayfs \
    squashfs-tools \
    xz \
    lz4 \
    zstd \
    bzip2 \
    xz-libs \
    lz4-libs \
    zstd-libs \
    brotli-libs \
    snappy-libs \
    zstd-libs \
    libaom \
    libdav1d \
    libde265 \
    libx264 \
    libx265 \
    vpx \
    opus \
    speex \
    libogg \
    libvorbis \
    flac \
    libksml \
    libpulse \
    alsa-lib \
    alsa-utils \
    alsa-plugins \
    bluez \
    bluez-utils \
    bluez-libs \
    libusb \
    libudev \
    libevdev \
    libinput \
    libxkbcommon \
    libx11 \
    libxcb \
    libxext \
    libxrandr \
    libxcomposite \
    libxdamage \
    libxfixes \
    libxrender \
    libxcursor \
    libxi \
    libxmu \
    libxt \
    libxau \
    libxdmcp \
    libdrm \
    libepoxy \
    libglvnd \
    libgl \
    libgles \
    libegl \
    mesa-egl \
    mesa-gles \
    mesa-libgl \
    mesa-libglw \
    mesa-dri \
    mesa-icd \
    libva \
    libva-utils \
    intel-media-libs \
    v4l-utils \
    v4l-utils-libs \
    libavutil \
    libswscale \
    libswresample \
    libavcodec \
    libavformat \
    libavfilter \
    libpostproc \
    ffmpeg \
    ffmpeg-headless \
    x264 \
    x265 \
    aom \
    dav1d \
    vpx \
    opus \
    speex \
    libogg \
    libvorbis \
    flac \
    gsm \
    gsm-libs \
    gsm-libs-libs \
    gsm-libs-libs \
    gsm-libs-libs \
    gsm-libs-libs 2>/dev/null || true

# Core packages that are essential
apk add --no-cache \
    linux \
    linux-headers \
    build-base \
    cmake \
    git \
    python3 \
    py3-pip \
    curl \
    ca-certificates \
    openrc \
    openrc-run \
    syslog-ng \
    openssh \
    wpa_supplicant \
    wireless-tools \
    util-linux \
    kmod \
    pciutils \
    mesa \
    vulkan-radeon-driver \
    radv \
    s6 \
    rsync \
    jq \
    inotify-tools \
    htop \
    lm_sensors \
    smartmontools \
    chrony \
    haveged \
    dbus \
    elogind \
    crond \
    nan \
    less \
    findutils \
    sed \
    grep \
    awk \
    busybox-extras 2>/dev/null || true

echo "  Packages installed."

# ---------- 2. llama.cpp ----------
echo "[2/6] Setting up llama.cpp..."
LLAMA_DIR=/opt/llama.cpp
mkdir -p "$LLAMA_DIR"

# Check if llama.cpp is already installed
if [ -x "$LLAMA_DIR/llama-server" ]; then
    echo "  llama.cpp already present at $LLAMA_DIR - skipping build."
else
    echo "  Cloning llama.cpp..."
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /tmp/llama.cpp
    echo "  Building with Vulkan support..."
    cmake -S /tmp/llama.cpp -B /tmp/llama.cpp/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN=ON \
        -DGGML_RPC=ON \
        -DCMAKE_INSTALL_PREFIX="$LLAMA_DIR" \
        -DBUILD_SHARED_LIBS=ON
    cmake --build /tmp/llama.cpp/build -j$(nproc)
    cmake --install /tmp/llama.cpp/build
    rm -rf /tmp/llama.cpp
    echo "  llama.cpp built and installed."
fi

# ---------- 3. PS5 LLM tools ----------
echo "[3/6] Installing PS5 LLM tools..."

# TUI and CLI
install -m 755 "$(dirname "$0")/bin/ps5llm-tui" /usr/bin/ps5llm-tui
install -m 755 "$(dirname "$0")/bin/ps5llm" /usr/bin/ps5llm
install -m 755 "$(dirname "$0")/bin/ps5llm-console" /usr/bin/ps5llm-console

# HF helper and utilities
install -m 755 "$(dirname "$0")/bin/ps5llm-hf" /usr/local/bin/ps5llm-hf
install -m 755 "$(dirname "$0")/bin/ram-valve.sh" /usr/local/bin/ram-valve.sh
install -m 755 "$(dirname "$0")/bin/wifi-watchdog.sh" /usr/local/bin/wifi-watchdog.sh

# Menu
mkdir -p /usr/local/lib
install -m 644 "$(dirname "$0")/lib/menu_hf.sh" /usr/local/lib/menu_hf.sh

echo "  Tools installed."

# ---------- 4. Init scripts ----------
echo "[4/6] Configuring init scripts..."
install -m 755 "$(dirname "$0")/init.d/llama-server" /etc/init.d/llama-server
install -m 755 "$(dirname "$0")/init.d/wpa_cli" /etc/init.d/wpa_cli
[ -f "$(dirname "$0")/init.d/wpa_supplicant" ] && \
    install -m 755 "$(dirname "$0")/init.d/wpa_supplicant" /etc/init.d/wpa_supplicant
[ -f "$(dirname "$0")/init.d/ps5-stage-firmware" ] && \
    install -m 755 "$(dirname "$0")/init.d/ps5-stage-firmware" /etc/init.d/ps5-stage-firmware

rc-update add llama-server default
rc-update add wpa_cli default
rc-update add wpa_supplicant default
rc-update add sshd default
rc-update add syslog-ng default
rc-update add chronyd default

echo "  Init scripts configured."

# ---------- 5. Directory structure ----------
echo "[5/6] Creating directory structure..."
mkdir -p /models
mkdir -p /var/lib/ps5llm-hf/jobs
mkdir -p /var/lib/ps5llm-hf/cache
mkdir -p /etc/llama
mkdir -p /etc/wpa_supplicant
mkdir -p /var/log

# Default configs (no personal data)
install -m 644 "$(dirname "$0")/etc/llama.conf" /etc/llama/llama.conf
install -m 600 "$(dirname "$0")/etc/wpa_supplicant.conf" /etc/wpa_supplicant/wpa_supplicant.conf

# Empty inventory
printf 'repo_id\trevision\tpath\tsize\tstatus\tquant\tformat\n' > /var/lib/ps5llm-hf/inventory.tsv

echo "  Directories created."

# ---------- 6. Final setup ----------
echo "[6/6] Final setup..."

# Set hostname (user can change)
echo "ps5llm" > /etc/hostname

# Enable services
rc-update add networking default 2>/dev/null || true

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Next steps:"
echo "  1. Configure network:  ps5llm wifi connect"
echo "  2. Download a model:   ps5llm-tui  (Hugging Face menu)"
echo "  3. Start the server:   rc-service llama-server start"
echo ""
echo "The system is ready. No personal data was included."
echo ""
