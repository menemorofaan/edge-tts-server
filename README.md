# Edge TTS Local Server & Translation Proxy

A lightweight, zero-configuration local Text-to-Speech (TTS) server powered by Microsoft Edge's online engine (`edge-tts`) and FastAPI. 

It provides an OpenAI-compatible `/v1/audio/speech` endpoint with interactive startup options for on-the-fly translation (via Google Translate) and **intelligent script-aware voice switching** to prevent synthesis errors.

---

## ✨ Features

- **Zero-Setup Polyglot Script**: The script runs directly via double-click on Windows (`.cmd`) and automatically installs all required dependencies (`fastapi`, `uvicorn`, `edge-tts`) on first launch.
- **Interactive Startup Menu**: Choose on launch whether to run without translation or auto-translate to English, Ukrainian, German, Russian, or any custom ISO language code.
- **Smart Voice Fallback (Anti-Crash)**:
  - Automatically identifies **Japanese** (Hiragana/Katakana), **Chinese** (CJK Kanji), and **Korean** (Hangul) characters and switches to native voices to avoid `NoAudioReceived` errors.
  - Automatically prevents Russian voices from crashing on purely Latin text.
- **OpenAI Compatible**: Works as a drop-in replacement for OpenAI TTS endpoints (`/v1/audio/speech`, `/v1/audio/voices`, `/v1/models`) in reader extensions (Marinara, Read Aloud), local LLM frontends, and apps.
- **Speed Multiplier Mapping**: Automatically translates standard numeric playback rates (e.g., `1.25x`) to Microsoft Edge percentage rates (e.g., `+25%`).

---

## 📋 Requirements

- **OS**: Windows 10 / 11
- **Python**: Python 3.8+ (Make sure to check **"Add Python to PATH"** during installation)

No manual `pip install` required.

---

## 🚀 How to Run

1. Clone or download this repository.
2. Double-click `tts_server.cmd`.
3. In the console window, select your desired translation mode:
   ```text
   ==================================================
              SELECT TRANSLATION MODE                
   ==================================================
   1. No translation [Default - Enter]
   2. English (en)
   3. Українська (uk)
   4. Deutsch (de)
   5. Русский (ru)
   6. Custom language code (e.g. ja, fr, es, zh...)
   ==================================================
   Select an option (1-6) [Enter = 1]:
   ```
4. The server will start locally at:
   ```text
   http://127.0.0.1:5050
   ```

---

## 🧠 Smart Script & Voice Mapping

When **Translation is Disabled (Mode 1)**, the server inspects incoming text scripts:
- **Japanese (Hiragana / Katakana)** $\rightarrow$ `ja-JP-NanamiNeural`
- **Chinese (Hanzi)** $\rightarrow$ `zh-CN-YunxiNeural`
- **Korean (Hangul)** $\rightarrow$ `ko-KR-InJoonNeural`
- **Cyrillic** $\rightarrow$ `ru-RU-DmitryNeural` / Ukrainian fallback
- **Latin** $\rightarrow$ switches to `en-US-ChristopherNeural` if the requested voice is strictly Russian.

When **Translation is Enabled**, text is translated to the chosen language first and synthesized with a matching native voice.

---

## 🔌 API Reference

### Health Check
- **Endpoint**: `GET /` or `GET /v1`
- **Response**: `{"status": "ok"}`

### List Voices
- **Endpoint**: `GET /v1/audio/voices`
- **Response**: `[{"voice_id": "...", "name": "..."}]`

### Speech Synthesis
- **Endpoint**: `POST /v1/audio/speech`
- **Headers**: `Content-Type: application/json`
- **Body Example**:
  ```json
  {
    "input": "Hello world! This is a test.",
    "voice": "ru-RU-DmitryNeural",
    "speed": 1.0
  }
  ```
- **Response**: Binary `audio/mpeg` stream.

#### Example `curl` Request:
```bash
curl -X POST http://127.0.0.1:5050/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d "{\"input\": \"Привет, мир!\", \"speed\": 1.1}" \
  --output speech.mp3
```

---

## ⚙️ Configuration

- **Port**: Default is `5050`. To change it, scroll to the bottom of the script and edit `port=5050` in `uvicorn.run(...)`.
- **Default Voices**: You can customize preferred voices for each language inside the `DEFAULT_VOICES` dictionary near the top of the script.

---

## ⚠️ Disclaimer

This server uses `edge-tts`, an unofficial Python module that communicates with Microsoft Edge's online TTS endpoints. It is intended for personal and educational use.
