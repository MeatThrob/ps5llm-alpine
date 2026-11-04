# PS5 LLM Alpine Distro

A clean, self-contained server based Alpine Linux distribution for running LLMs on PS5


## Download the full image

A ready-to-boot distro image (**everything except model files**) is published here:

**https://github.com/MeatThrob/ps5llm-alpine/releases/tag/image-2026.11.04**

Assets:

- `ps5llm-rootfs.img.zst.part-00` / `.part-01` — root filesystem (16 GiB ext4, expands on first boot)
- `ps5llm-boot.tar.zst` — EFI boot partition (kernel, initrd, cmdline)
- `SHA256SUMS` — checksums

Install:

```sh
# reassemble + decompress the root filesystem
cat ps5llm-rootfs.img.zst.part-* > ps5llm-rootfs.img.zst
sha256sum -c SHA256SUMS --ignore-missing
zstd -d ps5llm-rootfs.img.zst

# root filesystem -> partition 2 (ext4, label ps5llm)
sudo dd if=ps5llm-rootfs.img of=/dev/sdX2 bs=4M status=progress conv=fsync

# boot files -> partition 1 (FAT32, label BOOT)
sudo mkfs.vfat -F32 -n BOOT /dev/sdX1
sudo mount /dev/sdX1 /mnt
sudo tar -C /mnt -xf ps5llm-boot.tar.zst --zstd
sync && sudo umount /mnt
```

Then boot from the drive and run `ps5llm wifi connect`. The image ships with
**no models** — use `ps5llm-tui` → Hugging Face to download one.


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
