# Parkir QRIS Display

**Real-time display server untuk status pembayaran QRIS** — menampilkan info transaksi, plat nomor, tarif, dan QRIS payment di monitor. Komunikasi via SSE (Server-Sent Events).

## API Endpoints

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| `GET` | `/` | Halaman display utama |
| `GET` | `/bc` | Halaman display barcode |
| `GET` | `/stream` | SSE stream status real-time |
| `GET` | `/state` | State saat ini (JSON) |
| `GET` | `/photo/current` | Foto kendaraan terbaru |
| `POST` | `/qris/update` | Update status transaksi |
| `POST` | `/qris/idle` | Reset ke idle |

## State Fields

| Field | Deskripsi |
|-------|-----------|
| `status` | `idle` atau `active` |
| `notrans` | Nomor transaksi |
| `nopol` | Plat nomor kendaraan |
| `jenis_kend` | Jenis kendaraan |
| `jam_masuk` | Waktu masuk |
| `durasi` | Durasi parkir |
| `tarif` | Biaya parkir |
| `qris_text` | String QRIS pembayaran |
| `foto_path` | Path foto kendaraan |
| `outlet` | Nama outlet |
| `paid_by` | Metode pembayaran |

## Konfigurasi (`config.yaml`)

```yaml
server:
  port: 8001
  host: 0.0.0.0
foto_dir: Z:\Foto_Masuk
outlet_name: SISTEM PARKIR
```

## Instalasi

Jalankan `install.ps1` sebagai Administrator.

## Teknologi

- **FastAPI** — HTTP + SSE server
- **Server-Sent Events** — Push real-time ke browser
- **NSSM** — Windows service wrapper

---

Dikembangkan untuk **SMARTPARK** — Situsindo Prima.
