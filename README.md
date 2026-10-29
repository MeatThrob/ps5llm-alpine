# PS5 LLM Alpine Distro

A clean, self-contained server based Alpine Linux distribution for running LLMs on PS5


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
