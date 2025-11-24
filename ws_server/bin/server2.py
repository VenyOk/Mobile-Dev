import asyncio
import json
import re
from datetime import datetime
from pathlib import Path
import websockets
from websockets.exceptions import ConnectionClosedError

HOST = "0.0.0.0"
PORT = 8765
STATE_PATH = Path("state.json")

def analyze_text(text: str):
    tokens = [t for t in re.split(r"\s+", text.strip()) if t]
    count = len(tokens)
    length_hist = {}
    for t in tokens:
        l = len(t)
        length_hist[l] = length_hist.get(l, 0) + 1
    return {
        "type": "result",
        "original": text,
        "word_count": count,
        "length_hist": length_hist,
        "tokens": tokens,
        "updated_at": datetime.now().isoformat(timespec="seconds"),
    }

def log_request(client, text: str, result: dict):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ip = None
    port = None
    if client is not None and isinstance(client, tuple) and len(client) >= 2:
        ip, port = client[0], client[1]
    tokens = result.get("tokens", [])
    word_count = result.get("word_count", 0)
    length_hist = result.get("length_hist", {})
    preview = text.replace("\n", "\\n")
    if len(preview) > 200:
        preview = preview[:200] + "…"
    hist_lines = []
    for l in sorted(length_hist.keys()):
        hist_lines.append(f"  длина {l}: {length_hist[l]}")
    print(
        "\n".join(
            [
                "—" * 72,
                f"[{ts}] Запрос от {ip or '?'}:{port or '?'}",
                f"Исходный текст ({len(text)} симв.): \"{preview}\"",
                f"Слов: {word_count}",
                f"Список слов: {tokens}" if tokens else "Список слов: []",
                "Гистограмма длин:" if hist_lines else "Гистограмма длин: (пусто)",
                *hist_lines,
                "—" * 72,
            ]
        )
    )

def save_state(result: dict):
    payload = {
        "type": "restore",
        "original": result.get("original", ""),
        "word_count": result.get("word_count", 0),
        "length_hist": result.get("length_hist", {}),
        "updated_at": result.get("updated_at"),
    }
    tokens = result.get("tokens")
    if tokens is not None:
        payload["tokens"] = tokens
    STATE_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

def load_state():
    if not STATE_PATH.exists():
        return None
    try:
        data = json.loads(STATE_PATH.read_text(encoding="utf-8"))
        data["type"] = "restore"
        return data
    except Exception as e:
        print(f"[WARN] Не удалось прочитать {STATE_PATH}: {e}")
        return None

async def handler(websocket):
    snapshot = load_state()
    if snapshot:
        try:
            await websocket.send(json.dumps(snapshot, ensure_ascii=False))
        except ConnectionClosedError:
            return
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
            except json.JSONDecodeError:
                await websocket.send(
                    json.dumps(
                        {
                            "type": "error",
                            "message": "Expected JSON with {\"text\": \"...\"}",
                        },
                        ensure_ascii=False,
                    )
                )
                continue
            if data.get("type") == "restore":
                snap = load_state()
                if snap:
                    await websocket.send(json.dumps(snap, ensure_ascii=False))
                else:
                    await websocket.send(
                        json.dumps(
                            {
                                "type": "restore",
                                "original": "",
                                "word_count": 0,
                                "length_hist": {},
                                "updated_at": None,
                            },
                            ensure_ascii=False,
                        )
                    )
                continue
            text = data.get("text", "")
            result = analyze_text(text)
            log_request(websocket.remote_address, text, result)
            save_state(result)
            result_to_client = {
                "type": "result",
                "original": result["original"],
                "word_count": result["word_count"],
                "length_hist": result["length_hist"],
                "updated_at": result["updated_at"],
            }
            await websocket.send(json.dumps(result_to_client, ensure_ascii=False))
    except ConnectionClosedError:
        pass

async def main():
    print(f"Starting WebSocket server on ws://{HOST}:{PORT}")
    async with websockets.serve(
        handler, HOST, PORT, ping_interval=20, ping_timeout=20
    ):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
