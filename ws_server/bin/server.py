import asyncio
import json
import os
import websockets

STATE_FILE = "state.json"

# Глобальное состояние (одно на сервер)
state = {"a": 0.0, "b": 0.0}

def to_float(v):
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        return float(v.replace(",", ".").strip())
    raise ValueError("bad type")

def load_state():
    global state
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            a = to_float(data.get("a", 0))
            b = to_float(data.get("b", 0))
            state = {"a": a, "b": b}
            print(f"State loaded: {state}")
        except Exception as e:
            print(f"Failed to load state: {e}; using defaults")
    else:
        print("No state file; using defaults")

def save_state():
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, ensure_ascii=False, indent=2)
        print(f"State saved: {state}")
    except Exception as e:
        print(f"Failed to save state: {e}")

async def handler(ws):
    peer = ws.remote_address
    print(f"Client connected: {peer}")
    # При подключении — отправим текущее состояние
    await ws.send(json.dumps({"type": "state", **state}, ensure_ascii=False))
    try:
        async for message in ws:
            print(f"recv: {message}")
            try:
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "set_ab":
                    # обновим и сохраним
                    a = to_float(data.get("a", state["a"]))
                    b = to_float(data.get("b", state["b"]))
                    state["a"], state["b"] = a, b
                    save_state()
                    # ответим новым состоянием
                    await ws.send(json.dumps({"type": "state", **state}, ensure_ascii=False))

                elif msg_type == "get_state":
                    await ws.send(json.dumps({"type": "state", **state}, ensure_ascii=False))

                elif msg_type == "calculate":
                    # разрешаем не передавать a/b — берём сохранённые
                    a = to_float(data.get("a", state["a"]))
                    b = to_float(data.get("b", state["b"]))
                    op = str(data.get("operation", "+"))
                    if op == "+":
                        res = a + b
                    elif op == "-":
                        res = a - b
                    elif op in ("*", "x"):
                        res = a * b
                    elif op == "/":
                        if b == 0:
                            await ws.send(json.dumps({"type": "calculation_error", "message": "Деление на ноль невозможно"}, ensure_ascii=False))
                            continue
                        res = a / b
                    else:
                        await ws.send(json.dumps({"type": "calculation_error", "message": f"Неизвестная операция: {op}"}, ensure_ascii=False))
                        continue

                    print(f"calc: {a} {op} {b} = {res}")
                    await ws.send(json.dumps({"type": "calculation_result", "result": res}, ensure_ascii=False))

                else:
                    await ws.send(json.dumps({"type": "error", "message": f"Неизвестный тип сообщения: {msg_type}"}, ensure_ascii=False))

            except Exception as e:
                await ws.send(json.dumps({"type": "error", "message": f"Неверный формат/данные: {e}"}, ensure_ascii=False))
    except websockets.ConnectionClosed:
        print(f"Client disconnected: {peer}")

async def main():
    load_state()
    async with websockets.serve(handler, "0.0.0.0", 8080, max_size=2**20):
        print("✅ WebSocket server running on ws://0.0.0.0:8080")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
