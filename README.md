# Edge TTS Local Server

A lightweight, zero-configuration local Text-to-Speech (TTS) server powered by Microsoft Edge's online TTS engine (`edge-tts`) and FastAPI.

It exposes an OpenAI-compatible `/v1/audio/speech` endpoint, making it an easy drop-in replacement for OpenAI TTS in various tools, readers, web extensions (like Marinara / Read Aloud), and local AI frontends.

---

## ✨ Features

- **Double-Click & Run**: Hybrid polyglot scripts (`.cmd`) that launch Python directly and automatically install missing dependencies (`fastapi`, `uvicorn`, `edge-tts`).
- **OpenAI Compatible**: Supports standard endpoints (`/v1/audio/speech`, `/v1/audio/voices`, `/v1/models`).
- **Speed Normalization**: Automatically converts numeric multiplier speeds (e.g. `1.25x`) into Edge TTS percentage rates (e.g. `+25%`).
- **Two Flavors Available**:
  - **Standard (`tts_server.cmd`)**: Fast, direct speech synthesis without external network calls.
  - **With Translation (`tts_server_translator.cmd`)**: Automatically detects non-Cyrillic text and translates it to Russian via Google Translate before synthesizing.

---

## 📋 Requirements

- **OS**: Windows 10 / 11
- **Python**: Python 3.8+ installed (Make sure to check **"Add Python to PATH"** during installation).

No need to run `pip install` manually — the script installs required dependencies automatically on its first run.

---

## 🚀 Quick Start

1. Download or clone this repository.
2. Double-click either:
   - `tts_server.cmd` — for standard TTS.
   - `tts_server_translator.cmd` — for TTS with automatic English-to-Russian translation.
3. The server will start locally at:
   ```text
   http://127.0.0.1:5050
