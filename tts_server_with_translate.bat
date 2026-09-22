# 2>nul & @cls & @title Edge TTS Server & @chcp 65001 >nul & @goto #_undefined_# 2>nul || @python -x "%~f0" %*
import sys
import subprocess

# Automatic dependency check and installation
required_modules = {
    "fastapi": "fastapi",
    "uvicorn": "uvicorn",
    "edge_tts": "edge-tts"
}

for mod, pip_name in required_modules.items():
    try:
        __import__(mod)
    except ImportError:
        print(f"[SETUP] Library {pip_name} not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", pip_name])

import asyncio
import re
import urllib.request
import urllib.parse
import json
import msvcrt
from fastapi import FastAPI, Request
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
import edge_tts
import uvicorn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Target language (None = no translation)
TARGET_LANG = None
CACHED_ALL_VOICES = None

DEFAULT_VOICES = {
    "ru": "ru-RU-DmitryNeural",
    "en": "en-US-ChristopherNeural",
    "uk": "uk-UA-OstapNeural",
    "de": "de-DE-ConradNeural",
    "ja": "ja-JP-NanamiNeural",
    "es": "es-ES-AlvaroNeural",
    "fr": "fr-FR-HenriNeural",
    "it": "it-IT-DiegoNeural",
    "zh": "zh-CN-YunxiNeural",
    "ko": "ko-KR-InJoonNeural",
    "pl": "pl-PL-MarekNeural",
    "tr": "tr-TR-AhmetNeural",
    "pt": "pt-BR-AntonioNeural",
}

def has_cyrillic(text: str) -> bool:
    return bool(re.search('[\u0400-\u04FF]', text))

def translate_text(text: str, target_lang: str) -> str:
    url = (
        "https://translate.googleapis.com/translate_a/single?client=gtx"
        f"&sl=auto&tl={urllib.parse.quote(target_lang)}&dt=t&q="
        + urllib.parse.quote(text)
    )
    req = urllib.request.Request(
        url, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        result = json.loads(response.read().decode('utf-8'))
        return "".join([part[0] for part in result[0] if part[0]])

async def resolve_voice(text: str, target_lang: str | None, requested_voice: str) -> str:
    global CACHED_ALL_VOICES

    # 1. If translation language is selected, strictly match the voice to that language
    if target_lang:
        lang = target_lang.lower().strip()
        if lang in DEFAULT_VOICES:
            return DEFAULT_VOICES[lang]

        # Search dynamic list for custom ISO code
        try:
            if CACHED_ALL_VOICES is None:
                CACHED_ALL_VOICES = await edge_tts.list_voices()
            for v in CACHED_ALL_VOICES:
                locale = v.get("Locale", "").lower()
                if locale.startswith(f"{lang}-") or locale == lang:
                    return v["ShortName"]
        except Exception:
            pass
        return requested_voice

    # 2. If translation is disabled (None), auto-detect to prevent NoAudioReceived
    if re.search(r'[\u3040-\u30ff\u31f0-\u31ff]', text):  # Japanese Hiragana / Katakana
        return DEFAULT_VOICES["ja"]
    if re.search(r'[\u4e00-\u9fff]', text):              # Chinese / CJK Kanji
        return DEFAULT_VOICES["zh"]
    if re.search(r'[\uac00-\ud7af]', text):              # Korean Hangul
        return DEFAULT_VOICES["ko"]
    if has_cyrillic(text):
        return requested_voice if ("ru" in requested_voice.lower() or "uk" in requested_voice.lower()) else "ru-RU-DmitryNeural"
    if "ru-RU" in requested_voice and not has_cyrillic(text):
        # Prevent Russian voice from choking on pure Latin text
        return DEFAULT_VOICES["en"]

    return requested_voice

def select_target_language():
    global TARGET_LANG
    print("=" * 50)
    print("           SELECT TRANSLATION MODE                ")
    print("=" * 50)
    print("1. No translation [Default - Enter]")
    print("2. English (en)")
    print("3. Українська (uk)")
    print("4. Deutsch (de)")
    print("5. Русский (ru)")
    print("6. Custom language code (e.g. ja, fr, es, zh...)")
    print("=" * 50)

    choice = input("Select an option (1-6) [Enter = 1]: ").strip()

    if choice == "2":
        TARGET_LANG = "en"
        print("[CONFIG] Target language: English (en)\n")
    elif choice == "3":
        TARGET_LANG = "uk"
        print("[CONFIG] Target language: Українська (uk)\n")
    elif choice == "4":
        TARGET_LANG = "de"
        print("[CONFIG] Target language: Deutsch (de)\n")
    elif choice == "5":
        TARGET_LANG = "ru"
        print("[CONFIG] Target language: Русский (ru)\n")
    elif choice == "6":
        custom_code = input("Enter language code (e.g. ja, fr, es, zh): ").strip().lower()
        TARGET_LANG = custom_code if custom_code else None
        if TARGET_LANG:
            print(f"[CONFIG] Target language: {TARGET_LANG}\n")
        else:
            print("[CONFIG] Mode: No translation (original text).\n")
    else:
        TARGET_LANG = None
        print("[CONFIG] Mode: No translation (original text).\n")

@app.get("/")
@app.get("/v1")
@app.get("/v1/models")
async def health():
    return {"status": "ok"}

@app.get("/audio/voices")
@app.get("/v1/audio/voices")
async def voices():
    voice_id = DEFAULT_VOICES.get(TARGET_LANG, "ru-RU-DmitryNeural") if TARGET_LANG else "ru-RU-DmitryNeural"
    return [{"voice_id": voice_id, "name": voice_id}]

@app.post("/audio/speech")
@app.post("/v1/audio/speech")
async def speech(request: Request):
    data = await request.json()
    text = data.get("input", "")
    requested_voice = data.get("voice", "ru-RU-DmitryNeural")

    # 1. Parse client speed (default 1.0)
    try:
        speed = float(data.get("speed", 1.0))
    except (ValueError, TypeError):
        speed = 1.0

    # 2. Convert to Microsoft Edge TTS format (+25%, -15%) clamped to [-50%, +100%]
    rate_percent = int(round((speed - 1.0) * 100))
    rate_percent = max(-50, min(100, rate_percent))
    rate_str = f"{rate_percent:+d}%"

    if not text:
        return Response(status_code=400)

    print(f"\n[TTS] Received request ({len(text)} chars, speed: {speed:.2f}x -> {rate_str})")

    # 3. Translation logic
    if TARGET_LANG is None:
        print("[TTS] Translation disabled, speaking original text.")
    elif TARGET_LANG == "ru" and has_cyrillic(text):
        print("[TTS] Text already contains Cyrillic, skipping Russian translation.")
    else:
        print(f"[TTS] Translating text to [{TARGET_LANG}]...")
        try:
            translated = await asyncio.to_thread(translate_text, text, TARGET_LANG)
            if translated:
                text = translated
                print(f"[TTS] Successfully translated: {text[:75]}...")
        except Exception as e:
            print(f"[TTS TRANSLATION ERROR]: {e}")

    # 4. Resolve correct voice for the language
    voice = await resolve_voice(text, TARGET_LANG, requested_voice)
    print(f"[TTS] Using voice: [{voice}]")

    # 5. Generate audio via Edge TTS
    try:
        communicate = edge_tts.Communicate(text, voice, rate=rate_str)
        audio_data = b""
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_data += chunk["data"]

        if not audio_data:
            raise RuntimeError(f"Edge TTS returned no audio frames for voice '{voice}'.")

        print("[TTS] Audio generated and sent!")
        return Response(content=audio_data, media_type="audio/mpeg")
    except Exception as e:
        print(f"[TTS GENERATION ERROR]: {e}")
        return Response(content=str(e), status_code=500)

if __name__ == "__main__":
    select_target_language()

    while True:
        try:
            uvicorn.run(app, host="127.0.0.1", port=5050)
        except (KeyboardInterrupt, SystemExit):
            pass
        except Exception as e:
            print(f"\n[TTS ERROR]: {e}")

        while msvcrt.kbhit():
            msvcrt.getwch()

        print("\nPress any key to exit or [N] to restart server...", end="", flush=True)
        try:
            key = msvcrt.getwch()
            print()
            if key.lower() in ("n", "т"):
                print("[TTS] Restarting server...\n")
                continue
        except Exception:
            pass

        break
