# main.py — FastAPI QRIS Display Server
# Reads config from config.yaml at project root

import os, sys, json, asyncio
from datetime import datetime

import yaml
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, StreamingResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Literal
import uvicorn

# ─── Load config ─────────────────────────────────────────────
def load_config():
    """Load config.yaml. Walk up from script dir to find project root."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Look for config.yaml in script_dir, then parent, then grandparent
    for d in [script_dir, os.path.dirname(script_dir), os.path.dirname(os.path.dirname(script_dir))]:
        p = os.path.join(d, "config.yaml")
        if os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return yaml.safe_load(f)
    # Fallback
    return {"server": {"port": 8001, "host": "0.0.0.0"}, "foto_dir": "E:/FOTO", "outlet_name": "SISTEM PARKIR"}

_cfg = load_config()
SRV = _cfg.get("server", {})
HOST = SRV.get("host", "0.0.0.0")
PORT = SRV.get("port", 8001)
FOTO_DIR = _cfg.get("foto_dir", "E:/FOTO")
OUTLET_NAME = _cfg.get("outlet_name", "SISTEM PARKIR")

# ─── App setup ───────────────────────────────────────────────
app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ─── State global ────────────────────────────────────────────
current_state = {
    "status": "idle",
    "payment_method": "QRIS",
    "notrans": "",
    "nopol": "",
    "jenis_kend": "",
    "jam_masuk": "",
    "durasi": "",
    "tarif": 0,
    "qris_text": "",
    "foto_path": "",
    "outlet": OUTLET_NAME,
    "paid_by": "",
    "timestamp": ""
}

subscribers: list = []

class PaymentUpdate(BaseModel):
    status: Literal["preview", "waiting", "paid"]
    payment_method: Literal["QRIS", "CASH"] = "QRIS"
    notrans: str = ""
    nopol: str = ""
    jenis_kend: str = ""
    jam_masuk: str = ""
    durasi: str = ""
    tarif: int = Field(default=0, ge=0)
    qris_text: str = ""
    foto_path: str = ""
    outlet: str = ""
    paid_by: str = ""

    @field_validator("payment_method", mode="before")
    @classmethod
    def normalize_payment_method(cls, value):
        return str(value or "QRIS").strip().upper()

    @field_validator("status", mode="before")
    @classmethod
    def normalize_status(cls, value):
        return str(value or "").strip().lower()

    @model_validator(mode="after")
    def validate_qris_text(self):
        if self.status == "waiting" and self.payment_method == "QRIS" and not self.qris_text.strip():
            raise ValueError("qris_text wajib diisi untuk pembayaran QRIS waiting")
        return self

def empty_state():
    return {
        "status": "idle",
        "payment_method": "QRIS",
        "notrans": "",
        "nopol": "",
        "jenis_kend": "",
        "jam_masuk": "",
        "durasi": "",
        "tarif": 0,
        "qris_text": "",
        "foto_path": "",
        "outlet": OUTLET_NAME,
        "paid_by": "",
        "timestamp": datetime.now().isoformat(),
    }

async def broadcast(data: dict):
    payload = f"data: {json.dumps(data)}\n\n"
    dead = []
    for q in subscribers:
        try:
            q.put_nowait(payload)
        except Exception:
            dead.append(q)
    for d in dead:
        subscribers.remove(d)

@app.post("/qris/update")
async def qris_update(update: PaymentUpdate):
    body = update.model_dump()
    if body["status"] == "paid":
        provided_fields = update.model_fields_set
        method = body.get("payment_method", "QRIS")
        if "payment_method" not in provided_fields and body.get("paid_by"):
            method = body["paid_by"]
        method = str(method or "QRIS").upper()
        body["payment_method"] = method
        body["paid_by"] = body.get("paid_by") or method
        body["qris_text"] = ""
    elif body["status"] == "preview" or body["payment_method"] == "CASH":
        body["qris_text"] = ""

    current_state.clear()
    current_state.update(empty_state())
    current_state.update(body)
    current_state["timestamp"] = datetime.now().isoformat()
    await broadcast(current_state.copy())
    return JSONResponse({"ok": True})

@app.post("/qris/idle")
async def qris_idle():
    current_state.clear()
    current_state.update(empty_state())
    await broadcast(current_state.copy())
    return JSONResponse({"ok": True})

@app.get("/stream")
async def stream(request: Request):
    q: asyncio.Queue = asyncio.Queue()
    subscribers.append(q)
    async def event_gen():
        yield f"data: {json.dumps(current_state)}\n\n"
        try:
            while True:
                if await request.is_disconnected():
                    break
                try:
                    msg = await asyncio.wait_for(q.get(), timeout=15.0)
                    yield msg
                except asyncio.TimeoutError:
                    yield ": ping\n\n"
        finally:
            if q in subscribers:
                subscribers.remove(q)
    return StreamingResponse(event_gen(), media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

@app.get("/photo/current")
async def get_current_photo():
    path = current_state.get("foto_path", "")
    if path and os.path.exists(path):
        return FileResponse(path, media_type="image/jpeg",
            headers={"Cache-Control": "no-cache"})
    return JSONResponse({"error": "not found", "foto_path": path}, status_code=404)

@app.get("/state")
async def get_state():
    return JSONResponse({**current_state, "foto_dir": FOTO_DIR})

@app.get("/", response_class=HTMLResponse)
async def display_page():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "display.html")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

@app.get("/bc", response_class=HTMLResponse)
async def display_bc_page():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static", "display-bc.html")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

app.mount("/static", StaticFiles(
    directory=os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
), name="static")

if __name__ == "__main__":
    print(f"[INFO] FOTO_DIR = {FOTO_DIR}")
    print(f"[INFO] OUTLET   = {OUTLET_NAME}")
    print(f"[INFO] Listening on {HOST}:{PORT}")
    uvicorn.run("main:app", host=HOST, port=PORT, reload=False)
