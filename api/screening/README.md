# Screening OCR + YOLOv8

Folder ini berisi engine screening dokumen untuk endpoint:

- `POST sipora_api.php?action=screen_document`

Engine mendukung:

- `DOCX`: ekstraksi teks + OCR pada gambar embedded di dokumen.
- `PDF`: ekstraksi teks + OCR dari render halaman.
- YOLOv8 untuk deteksi elemen layout jika model tersedia.

## Instalasi Python dependency

```bash
pip install -r api/screening/requirements.txt
```

## Prasyarat sistem

- Python 3.10+.
- Tesseract OCR terpasang di sistem.
- Model YOLOv8 untuk layout dokumen, jika ingin deteksi layout aktif.

## Instalasi Windows

1. Install Tesseract OCR dari installer Windows.
2. Pastikan `tesseract.exe` bisa dipanggil dari terminal, atau set env `TESSERACT_CMD` ke lokasi executable.
3. Install dependency Python:

```powershell
python -m pip install -r api/screening/requirements.txt
```

4. Jika memakai model YOLOv8 custom, simpan file `.pt` di folder lokal lalu set `YOLOV8_MODEL_PATH` ke file tersebut.

## Konfigurasi

- Pastikan `python` bisa dipanggil dari environment web server.
- Opsional set path executable python lewat env `PYTHON_EXECUTABLE`.
- Opsional aktifkan YOLOv8 dengan env `YOLOV8_MODEL_PATH` ke file model `.pt`.
- OCR bisa dikontrol lewat env berikut:
  - `TESSERACT_CMD` atau `TESSERACT_PATH` untuk lokasi executable Tesseract.
  - `OCR_LANG` untuk bahasa OCR, default `ind+eng`.
  - `OCR_CONFIG` untuk opsi Tesseract, default `--psm 6`.

Contoh (Windows):

```powershell
setx PYTHON_EXECUTABLE "C:\\Python312\\python.exe"
setx TESSERACT_CMD "C:\\Program Files\\Tesseract-OCR\\tesseract.exe"
setx YOLOV8_MODEL_PATH "C:\\models\\yolov8n.pt"
```

## Catatan

- OCR membutuhkan engine Tesseract terpasang di sistem.
- Jika model YOLOv8 tidak ada, screening tetap berjalan dalam mode OCR/text-only.
- Untuk hasil layout yang lebih akurat, gunakan model YOLOv8 yang dilatih khusus untuk dokumen, bukan model umum COCO.
