# PS5 LLM Alpine Distro

A clean, self-contained Alpine Linux distribution for running LLMs on PS5 hardware (or any x86_64 box with an AMD GPU). Ships with llama.cpp (Vulkan), a TUI for model management, Hugging Face integration, and WiFi tools.

**No personal data included** — no WiFi passwords, IP addresses, model files, or API tokens. Fresh slate for every install.

## Requirements

- **Hardware:** x86_64 CPU + AMD GPU (RADV/Vulkan capable)
- **Base OS:** Alpine Linux edge (x86_64)
- **RAM:** 2 GB minimum (8 GB recommended for 27B models)
- **Storage:** 50 GB+ free for models

## Quick Start

1. Install fresh Alpine Linux edge (x86_64) to your target device
2. Clone this repo on the target:
   ```sh
   git clone https://github.com/MeatThrob/ps5llm-alpine.git /tmp/ps5llm-alpine
   ```
3. Run the installer:
   ```sh
   sh /tmp/ps5llm-alpine/scripts/install.sh
   ```
4. Connect to WiFi:
   ```sh
   ps5llm wifi connect
   ```
5. Open the TUI and download a model:
   ```sh
   ps5llm-tui
   ```
   → Huggingface Models → Browse → pick a model → Download

6. Start the LLM server:
   ```sh
   rc-service llama-server start
   ```

## What's Included

| Component | Path | Description |
|-----------|------|-------------|
| llama.cpp | `/opt/llama.cpp/` | Vulkan + CPU + RPC backend |
| TUI | `/usr/bin/ps5llm-tui` | Full terminal UI for model management |
| CLI | `/usr/bin/ps5llm` | Command-line interface |
| HF Helper | `/usr/local/bin/ps5llm-hf` | Hugging Face API wrapper |
| HF Menu | `/usr/local/lib/menu_hf.sh` | TUI Hugging Face submenu |
| RAM Valve | `/usr/local/bin/ram-valve.sh` | Memory pressure management |
| WiFi Watchdog | `/usr/local/bin/wifi-watchdog.sh` | WiFi connection keepalive |
| Init: llama-server | `/etc/init.d/llama-server` | OpenRC service for LLM server |
| Init: wpa_cli | `/etc/init.d/wpa_cli` | WPA CLI supervisor |
| Models dir | `/models/` | Empty — you add your own |
| HF state | `/var/lib/ps5llm-hf/` | Empty — jobs, inventory, cache |

## Configuration

### LLM Server (`/etc/llama/llama.conf`)

```
MODEL=              # Path to your .gguf model (set after download)
HOST=0.0.0.0
PORT=8080
CONTEXT=8192
GPU_LAYERS=999      # Offload all layers to GPU
FLASH_ATTN=on
CACHE_K=q4_0
CACHE_V=q4_0
BATCH=256
UBATCH=64
```

### WiFi

Use the TUI or CLI to connect:
```sh
ps5llm wifi connect
```
Networks are stored in `/etc/wpa_supplicant/wpa_supplicant.conf`.

## Hugging Face Integration

The TUI includes a full Hugging Face browser:
- **Browse** — models by popularity
- **Community** — by category (Official, Fine-Tunes, Coding, Uncensored)
- **Search** — by name/tag
- **Installed** — local model management
- **Downloads** — active/completed download jobs
- **Authentication** — HF token management

Downloads run in the background. The TUI stays responsive.

## Building from Source (llama.cpp)

The installer clones and builds llama.cpp with:
- `GGML_VULKAN=ON` (AMD GPU)
- `GGML_RPC=ON` (remote inference)
- Shared libs

If you need a custom build:
```sh
git clone https://github.com/ggml-org/llama.cpp.git
cmake -S llama.cpp -B llama.cpp/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_VULKAN=ON \
    -DGGML_RPC=ON \
    -DCMAKE_INSTALL_PREFIX=/opt/llama.cpp \
    -DBUILD_SHARED_LIBS=ON
cmake --build llama.cpp/build -j$(nproc)
cmake --install llama.cpp/build
```

## Repo Structure

```
ps5llm-alpine/
├── README.md
├── packages.txt              # Full Alpine package list
├── bin/
│   ├── ps5llm-tui           # Terminal UI
│   ├── ps5llm               # CLI
│   ├── ps5llm-console       # Console wrapper
│   ├── ps5llm-hf            # HF API helper
│   ├── ram-valve.sh         # RAM management
│   └── wifi-watchdog.sh     # WiFi keepalive
├── lib/
│   └── menu_hf.sh           # HF menu (sourced by TUI)
├── init.d/
│   ├── llama-server         # LLM server service
│   ├── wpa_cli              # WPA CLI service
│   ├── wpa_supplicant       # WPA supplicant service
│   └── ps5-stage-firmware   # PS5 firmware staging
├── etc/
│   ├── llama.conf           # Default LLM config (no personal data)
│   └── wpa_supplicant.conf  # Clean WiFi config (no networks)
└── scripts/
    └── install.sh           # One-shot installer
```

## Privacy

This distro contains **zero** personal data:
- ❌ No WiFi passwords/SSIDs
- ❌ No IP addresses
- ❌ No LLM model files
- ❌ No Hugging Face tokens
- ❌ No download history
- ❌ No SSH keys
- ❌ No hostname-specific configs

Every install is a fresh slate.

## License

See individual file headers. llama.cpp is under MIT.
