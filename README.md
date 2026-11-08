# PS5 LLM Alpine Distro

A clean, self-contained server based Alpine Linux distribution for running LLMs on PS5


## Download the full image

A ready-to-boot, **fully sanitized** distro image (**everything except model files**) is published here:

**https://github.com/MeatThrob/ps5llm-alpine/releases/tag/image-2026.11.04**

Asset: **`ps5llm-alpine.img.xz`** — one complete GPT disk image (EFI boot + root filesystem), ready to flash.

- Size: `1.47 GiB (1,574,350,240 bytes)`
- SHA256: `3c8fe7632e11b7e7c192e2b727127c4d47f60aa4ab6352316eed5d04040bd474`

Flash it to a **whole drive** (not a partition). This erases the entire drive:

```sh
xz -dc ps5llm-alpine.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

> Replace `/dev/sdX` with the target drive (for example `/dev/sdb`, or `/dev/disk4` on macOS). Double-check the device before running.

On first boot the root partition and ext4 filesystem expand automatically to fill the drive, so all remaining space is available for models under `/models`.

The image ships with **no models** and **no WiFi network configured**. Connect the PS5 to HDMI with a keyboard, use the on-screen TUI to join WiFi, then download a model via **Hugging Face (browse/download)**.

Sanitized: no WiFi SSIDs/PSKs, no IP or router information, no MAC addresses, no machine-id, no SSH host keys, no shell history, and no personal configs. Fresh SSH host keys are generated on first boot.

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
5. download a model:
   ```sh
   ps5llm-tui
   ```
   → Huggingface Models → Browse → pick a model → Download

6. Start the LLM server:
   ```sh
   rc-service llama-server start
   ```


## License

See individual file headers. llama.cpp is under MIT.
