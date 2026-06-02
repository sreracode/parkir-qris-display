# Parkir QRIS Display

FastAPI-based real-time display server for QRIS parking payment status. Displays transaction info, vehicle plate, tariff, and QRIS payment text on a monitor. Communicates via SSE (Server-Sent Events).

## Folder Structure

```
parkir-qris-display/
├── config.yaml          # Central configuration
├── requirements.txt     # Python dependencies
├── install.bat          # NSSM Windows service installer
├── .gitignore
├── README.md
└── src/
    ├── main.py          # FastAPI server
    ├── __init__.py
    └── static/
        ├── display.html     # Main display page
        └── display-bc.html  # Barcode-reader display page
```

## Configuration

Edit `config.yaml`:

```yaml
server:
  port: 8001
  host: 0.0.0.0
foto_dir: E:/FOTO           # Directory for parking photos
outlet_name: SISTEM PARKIR  # Outlet name displayed on screen
```

## Installation (Windows Service)

1. Install [NSSM](https://nssm.cc/download) and place `nssm.exe` in your PATH.
2. Run as Administrator:
   ```
   install.bat
   ```

The service will auto-start and listen on the port configured in `config.yaml`.

## Manual Run (Development)

```bash
cd parkir-qris-display
pip install -r requirements.txt
python src/main.py
```

## API Endpoints

| Method | Path             | Description                         |
| ------ | ---------------- | ----------------------------------- |
| GET    | `/`              | Main display page                   |
| GET    | `/bc`            | Barcode-reader display page         |
| GET    | `/stream`        | SSE stream of current state         |
| GET    | `/state`         | Current state as JSON               |
| GET    | `/photo/current` | Current parking photo (JPEG)        |
| POST   | `/qris/update`   | Update transaction state            |
| POST   | `/qris/idle`     | Reset to idle state                 |

## State Fields

| Field        | Description                              |
| ------------ | ---------------------------------------- |
| status       | `idle` or `active`                       |
| notrans      | Transaction number                       |
| nopol        | Vehicle plate number                     |
| jenis_kend   | Vehicle type                             |
| jam_masuk    | Entry time                               |
| durasi       | Duration                                 |
| tarif        | Parking fee                              |
| qris_text    | QRIS payment string                      |
| foto_path    | Path to vehicle photo                    |
| outlet       | Outlet name                              |
| paid_by      | Payment method                           |
| timestamp    | Last update ISO timestamp                |
