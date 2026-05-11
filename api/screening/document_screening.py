#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple


@dataclass(frozen=True)
class Rule:
    min_heading_count: int
    min_justified_ratio: float
    required_keywords: Tuple[str, ...]


RULES = {
    "skripsi": Rule(5, 0.65, ("BAB I", "BAB II", "BAB III")),
    "thesis": Rule(5, 0.65, ("BAB I", "BAB II", "BAB III")),
    "tesis": Rule(5, 0.65, ("BAB I", "BAB II", "BAB III")),
    "disertasi": Rule(6, 0.70, ("BAB I", "BAB II", "BAB III")),
    "laporan pkl": Rule(3, 0.60, ("PENDAHULUAN",)),
    "artikel ilmiah": Rule(4, 0.55, ("ABSTRAK", "PENDAHULUAN")),
}

DEFAULT_RULE = Rule(3, 0.55, ("PENDAHULUAN",))


def _safe_import_ocr():
    try:
        import pytesseract  # type: ignore

        configured_cmd = _resolve_tesseract_cmd()
        if configured_cmd is None:
            return None

        pytesseract.pytesseract.tesseract_cmd = configured_cmd
        return pytesseract
    except Exception:
        return None


def _safe_import_fitz():
    try:
        import fitz  # type: ignore

        return fitz
    except Exception:
        return None


def _safe_import_docx():
    try:
        from docx import Document  # type: ignore

        return Document
    except Exception:
        return None


def _safe_import_yolo():
    try:
        from ultralytics import YOLO  # type: ignore

        return YOLO
    except Exception:
        return None


def _resolve_tesseract_cmd() -> str | None:
    configured = (
        os.getenv("TESSERACT_CMD", "").strip()
        or os.getenv("TESSERACT_PATH", "").strip()
        or os.getenv("TESSERACT_EXE", "").strip()
    )
    if configured:
        candidate = Path(configured)
        if candidate.is_dir():
            candidate = candidate / "tesseract.exe"
        if candidate.exists():
            return str(candidate)

    discovered = shutil.which("tesseract")
    if discovered:
        return discovered

    common_windows_paths = [
        Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe"),
        Path(r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"),
    ]
    for path in common_windows_paths:
        if path.exists():
            return str(path)

    return None


def _normalize_text(lines: List[str]) -> List[str]:
    normalized = []
    for line in lines:
        clean = re.sub(r"\s+", " ", line).strip()
        if clean:
            normalized.append(clean)
    return normalized


def _extract_docx_text(path: Path) -> Tuple[List[str], List[bytes]]:
    text_lines: List[str] = []
    image_blobs: List[bytes] = []

    docx_document = _safe_import_docx()
    if docx_document is not None:
        doc = docx_document(str(path))
        for p in doc.paragraphs:
            if p.text:
                text_lines.append(p.text)

    # Embedded images are read directly from DOCX zip package.
    import zipfile

    with zipfile.ZipFile(path, "r") as zf:
        for entry in zf.namelist():
            lower = entry.lower()
            if lower.startswith("word/media/") and lower.endswith((".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".webp")):
                image_blobs.append(zf.read(entry))

    return _normalize_text(text_lines), image_blobs


def _extract_pdf_text_and_images(path: Path, max_pages: int = 8):
    fitz = _safe_import_fitz()
    if fitz is None:
        return [], [], 0

    text_lines: List[str] = []
    page_images = []

    pdf = fitz.open(str(path))
    page_count = min(len(pdf), max_pages)
    for i in range(page_count):
        page = pdf[i]
        extracted = page.get_text("text")
        if extracted:
            text_lines.extend(extracted.splitlines())

        pix = page.get_pixmap(dpi=220)
        image_bytes = pix.tobytes("png")
        page_images.append(image_bytes)

    pdf.close()
    return _normalize_text(text_lines), page_images, page_count


def _ocr_from_images(image_blobs: List[bytes]) -> List[str]:
    pytesseract = _safe_import_ocr()
    if pytesseract is None:
        return []

    try:
        from PIL import Image
        from io import BytesIO
    except Exception:
        return []

    ocr_lines: List[str] = []
    ocr_lang = os.getenv("OCR_LANG", "ind+eng").strip() or "ind+eng"
    ocr_config = os.getenv("OCR_CONFIG", "--psm 6").strip()
    for blob in image_blobs:
        try:
            image = Image.open(BytesIO(blob))
            text = pytesseract.image_to_string(image, lang=ocr_lang, config=ocr_config)
            if text:
                ocr_lines.extend(text.splitlines())
        except Exception:
            continue

    return _normalize_text(ocr_lines)


def _yolo_layout_analysis(image_blobs: List[bytes], confidence: float = 0.35) -> Tuple[int, bool]:
    model_path = os.getenv("YOLOV8_MODEL_PATH", "").strip()
    if not model_path:
        return 0, False

    yolo_cls = _safe_import_yolo()
    if yolo_cls is None:
        return 0, False

    model_file = Path(model_path)
    if not model_file.exists():
        return 0, False

    try:
        from PIL import Image
        from io import BytesIO
    except Exception:
        return 0, False

    detections = 0
    model = yolo_cls(str(model_file))

    for blob in image_blobs:
        try:
            image = Image.open(BytesIO(blob)).convert("RGB")
            results = model.predict(source=image, conf=confidence, verbose=False)
            if not results:
                continue
            first = results[0]
            boxes = getattr(first, "boxes", None)
            if boxes is not None:
                detections += len(boxes)
        except Exception:
            continue

    return detections, True


def _calculate_justified_ratio(lines: List[str]) -> float:
    if not lines:
        return 0.0

    lengths = [len(line) for line in lines if len(line) > 10]
    if not lengths:
        return 0.0

    median_len = statistics.median(lengths)
    threshold = max(45, int(median_len * 0.8))
    near_full = [length for length in lengths if length >= threshold]
    return len(near_full) / len(lengths)


def _is_heading(line: str) -> bool:
    clean = line.strip()
    if not clean:
        return False

    if re.match(r"^(BAB\s+[IVXLC0-9]+|[0-9]+(\.[0-9]+)+)\b", clean, flags=re.IGNORECASE):
        return True

    if len(clean) <= 72 and clean.upper() == clean and re.search(r"[A-Z]", clean):
        return True

    return False


def screen_document(input_path: Path, doc_type: str) -> dict:
    suffix = input_path.suffix.lower()
    normalized_type = doc_type.strip().lower()
    display_type = normalized_type if normalized_type else "dokumen umum"
    rule = RULES.get(normalized_type, DEFAULT_RULE)

    text_lines: List[str] = []
    image_blobs: List[bytes] = []
    page_count = 0

    if suffix == ".docx":
        text_lines, image_blobs = _extract_docx_text(input_path)
    elif suffix == ".pdf":
        text_lines, image_blobs, page_count = _extract_pdf_text_and_images(input_path)
    else:
        return {
            "can_analyze": False,
            "passed": False,
            "summary": "Format file tidak didukung untuk screening.",
            "score": 0,
            "total_paragraphs": 0,
            "heading_count": 0,
            "justified_body_ratio": 0,
            "checks": ["Gunakan format DOCX atau PDF."],
            "engine": "unsupported",
            "total_pages": 0,
        }

    ocr_ready = _safe_import_ocr() is not None
    ocr_lines = _ocr_from_images(image_blobs)
    combined_lines = _normalize_text(text_lines + ocr_lines)

    heading_count = sum(1 for line in combined_lines if _is_heading(line))
    body_lines = [line for line in combined_lines if not _is_heading(line)]
    justified_ratio = _calculate_justified_ratio(body_lines)

    full_text_upper = " ".join(combined_lines).upper()
    keyword_flags = [keyword.upper() in full_text_upper for keyword in rule.required_keywords]

    has_heading = heading_count >= rule.min_heading_count
    has_justified = justified_ratio >= rule.min_justified_ratio
    has_keywords = all(keyword_flags)

    yolo_box_count, yolo_ready = _yolo_layout_analysis(image_blobs)

    checks = [
        f"Heading terdeteksi {heading_count} (minimal {rule.min_heading_count})"
        if has_heading
        else f"Heading kurang: {heading_count} (minimal {rule.min_heading_count})",
        f"Estimasi paragraf rapi {justified_ratio * 100:.1f}%"
        if has_justified
        else f"Estimasi paragraf rapi {justified_ratio * 100:.1f}% (minimal {rule.min_justified_ratio * 100:.0f}%)",
        (
            f"Bagian wajib ditemukan ({', '.join(rule.required_keywords)})"
            if has_keywords
            else f"Bagian wajib belum lengkap ({', '.join(rule.required_keywords)})"
        ),
    ]

    if yolo_ready:
        checks.append(f"YOLOv8 mendeteksi {yolo_box_count} elemen layout pada dokumen.")
    else:
        checks.append("YOLOv8 tidak aktif atau model belum terkonfigurasi (set YOLOV8_MODEL_PATH).")

    passed_checks = sum(1 for flag in [has_heading, has_justified, has_keywords] if flag)
    score = (passed_checks / 3.0) * 100.0
    passed = passed_checks == 3

    if ocr_ready and yolo_ready:
        engine = "yolov8+ocr"
    elif ocr_ready:
        engine = "ocr-only"
    elif yolo_ready:
        engine = "yolov8-only"
    else:
        engine = "text-only"

    summary = (
        f"Screening selesai untuk {display_type}."
        if passed
        else f"Format dokumen belum memenuhi aturan dasar untuk {display_type}."
    )

    return {
        "can_analyze": True,
        "passed": passed,
        "summary": summary,
        "score": round(score, 2),
        "total_paragraphs": len(combined_lines),
        "heading_count": heading_count,
        "justified_body_ratio": round(justified_ratio, 4),
        "checks": checks,
        "engine": engine,
        "total_pages": page_count,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--type", default="")
    args = parser.parse_args()

    path = Path(args.input)
    if not path.exists() or not path.is_file():
        print(
            json.dumps(
                {
                    "can_analyze": False,
                    "passed": False,
                    "summary": "File input screening tidak ditemukan.",
                    "score": 0,
                    "total_paragraphs": 0,
                    "heading_count": 0,
                    "justified_body_ratio": 0,
                    "checks": ["Pastikan file upload berhasil diterima server."],
                    "engine": "none",
                    "total_pages": 0,
                },
                ensure_ascii=True,
            )
        )
        return

    try:
        result = screen_document(path, args.type)
    except Exception as exc:
        result = {
            "can_analyze": False,
            "passed": False,
            "summary": "Terjadi kesalahan saat screening OCR/YOLOv8.",
            "score": 0,
            "total_paragraphs": 0,
            "heading_count": 0,
            "justified_body_ratio": 0,
            "checks": [f"Error: {exc}"],
            "engine": "error",
            "total_pages": 0,
        }

    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    main()
