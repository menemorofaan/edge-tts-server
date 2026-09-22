# 2>nul & @cls & @title Edge TTS Server & @chcp 65001 >nul & @goto #_undefined_# 2>nul || @python -x "%~f0" %*
import sys
import subprocess

# Автоматическая проверка и доустановка зависимостей
required_modules = {
    "fastapi": "fastapi",
    "uvicorn": "uvicorn",
    "edge_tts": "edge-tts"
}

for mod, pip_name in required_modules.items():
    try:
        __import__(mod)
    except ImportError:
        print(f"[SETUP] Библиотека {pip_name} не найдена. Устанавливаю...")
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

def has_cyrillic(text: str) -> bool:
    return bool(re.search('[\u0400-\u04FF]', text))

def translate_text(text: str) -> str:
    url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ru&dt=t&q=" + urllib.parse.quote(text)
    req = urllib.request.Request(
        url, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
    )
    with urllib.request.urlopen(req, timeout=10) as response:
        result = json.loads(response.read().decode('utf-8'))
        return "".join([part[0] for part in result[0] if part[0]])

@app.get("/")
@app.get("/v1")
@app.get("/v1/models")
async def health():
    return {"status": "ok"}

@app.get("/audio/voices")
@app.get("/v1/audio/voices")
async def voices():
    return [{"voice_id": "ru-RU-DmitryNeural", "name": "Dmitry"}]

@app.post("/audio/speech")
@app.post("/v1/audio/speech")
async def speech(request: Request):
    data = await request.json()
    text = data.get("input", "")
    voice = data.get("voice", "ru-RU-DmitryNeural")

    # 1. Забираем скорость от Marinara (по умолчанию 1.0)
    try:
        speed = float(data.get("speed", 1.0))
    except (ValueError, TypeError):
        speed = 1.0

    # 2. Конвертируем в формат Microsoft (+25%, -15%) с ограничением от -50% до +100%
    rate_percent = int(round((speed - 1.0) * 100))
    rate_percent = max(-50, min(100, rate_percent))
    rate_str = f"{rate_percent:+d}%"

    if not text:
        return Response(status_code=400)

    print(f"\n[TTS] Получен запрос на озвучку ({len(text)} симв., скорость: {speed:.2f}x -> {rate_str})")

    # Перевод при необходимости
    if not has_cyrillic(text):
        print("[TTS] Текст на английском. Перевожу на русский...")
        try:
            translated = await asyncio.to_thread(translate_text, text)
            if translated:
                text = translated
                print(f"[TTS] Успешно переведено: {text[:75]}...")
        except Exception as e:
            print(f"[TTS ОШИБКА ПЕРЕВОДА]: {e}")
    else:
        print("[TTS] Текст уже на кириллице, озвучиваю как есть.")

    # 3. Передаём rate в генератор звука
    communicate = edge_tts.Communicate(text, voice, rate=rate_str)
    audio_data = b""
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio_data += chunk["data"]

    print("[TTS] Звук сгенерирован и отправлен!")
    return Response(content=audio_data, media_type="audio/mpeg")

if __name__ == "__main__":
    while True:
        try:
            uvicorn.run(app, host="127.0.0.1", port=5050)
        except (KeyboardInterrupt, SystemExit):
            pass
        except Exception as e:
            print(f"\n[TTS ОШИБКА]: {e}")

        while msvcrt.kbhit():
            msvcrt.getwch()

        print("\nНажмите любую клавишу для выхода или [N] для отмены...", end="", flush=True)
        try:
            key = msvcrt.getwch()
            print()
            if key.lower() in ("n", "т"):
                print("[TTS] Отмена выхода. Перезапуск сервера...\n")
                continue
        except Exception:
            pass

        break