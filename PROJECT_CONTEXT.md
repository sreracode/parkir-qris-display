# PROJECT_CONTEXT — parkir-qris-display

## Fungsi Utama
Server tampilan QR code pembayaran di monitor kedua. SMARTPARK mengirim data QRIS melalui REST API, service ini menampilkannya di browser via Server-Sent Events (SSE).

## Teknologi
- **Bahasa:** Python 3.11
- **Framework:** FastAPI + Uvicorn
- **Frontend:** HTML + JavaScript (SSE client)
- **Config:** YAML

## Entry Point
- **File:** `src/main.py`
- **Port:** 8001
- **Run:** `uvicorn main:app --host 0.0.0.0 --port 8001`

## File/Folder Penting
| Path | Fungsi |
|---|---|
| `src/main.py` | API server, SSE, state management |
| `src/static/display.html` | Halaman display utama (25KB) |
| `src/static/display-bc.html` | Halaman display barcode |
| `src/static/displayold.html` | Versi lama |
| `config.yaml` | Port, foto_dir, outlet_name |
| `install.bat` / `install.ps1` | Install script |

## API Endpoints
| Method | Path | Fungsi |
|---|---|---|
| POST | `/qris/update` | SMARTPARK kirim data QRIS baru |
| POST | `/qris/idle` | Reset ke tampilan idle |
| GET | `/stream` | SSE stream (real-time push) |
| GET | `/photo/current` | Foto kendaraan terkini |
| GET | `/state` | JSON state terkini |
| GET | `/` | Halaman display |
| GET | `/bc` | Halaman barcode |

## Data Flow
```
SMARTPARK → POST /qris/update (JSON)
         → SSE /stream broadcast
         → Browser display.html update UI
```

## State yang Disimpan
```json
{
  "status": "idle|active",
  "notrans": "...",
  "nopol": "...",
  "jenis_kend": "...",
  "jam_masuk": "...",
  "durasi": "...",
  "tarif": 0,
  "qris_text": "...",
  "foto_path": "E:/FOTO/...",
  "outlet": "RSOP PURWOKERTO",
  "paid_by": "...",
  "timestamp": "..."
}
```

## Koreksi Hasil Scan Source 2026-06-10

- State service bisa `idle`, `waiting`, atau `paid`. SMARTPARK mengirim `waiting` saat QR ditampilkan dan `paid` saat pembayaran sukses.
- Endpoint `/photo/current` memakai `foto_path` dari state jika file tersedia.
- `config.yaml` yang ditemukan berisi `outlet_name: Menara Teratai`, tetapi SMARTPARK mengirim field outlet dari `namaqris` (`RSOP PURWOKERTO` di config yang ditemukan).
- Service dijalankan langsung oleh `src/main.py` dengan `uvicorn.run()` memakai host/port dari `config.yaml`.

## Relasi
- **SMARTPARK:** Client utama — POST data QRIS via `QrisDisplaySender.bas`
- **SMARTPARK VB6:** `ShowQrisOnSecondMonitor()` — alternatif tanpa service

## Risiko Jika Mati/Diubah
- QR code tidak tampil di monitor kedua
- Customer tidak bisa scan QR
- Tidak kritis — QRIS masih bisa via monitor utama
- API endpoint diubah → SMARTPARK error

## Catatan Debugging
- Cek port: `curl http://localhost:8001/state`
- Buka browser: `http://localhost:8001/`
- SSE test: `curl http://localhost:8001/stream`
- Log: `logs/stderr.log`, `logs/stdout.log`
- Konfigurasi: `foto_dir` harus valid, `outlet_name` untuk display
