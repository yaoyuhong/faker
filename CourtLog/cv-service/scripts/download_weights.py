"""Download TrackNet pretrained weights.

Usage (from cv-service/):
  python scripts/download_weights.py

Weights source: yastrebksv/TrackNet README (Google Drive).
"""

from __future__ import annotations

import sys
from pathlib import Path

MODELS_DIR = Path(__file__).resolve().parent.parent / "models"
WEIGHTS_PATH = MODELS_DIR / "tracknet.pth"

# Public mirror instructions — Google Drive direct download often needs gdown
GDRIVE_FILE_ID = "1XEYZ4myUN7QT-NeBYJI0xteLsvs-ZAOl"


def main() -> None:
    if WEIGHTS_PATH.exists():
        print(f"Already exists: {WEIGHTS_PATH}")
        return

    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    try:
        import gdown
    except ImportError:
        print("Install gdown: pip install gdown")
        print(f"Or manually download weights to: {WEIGHTS_PATH}")
        print(f"Google Drive ID: {GDRIVE_FILE_ID}")
        sys.exit(1)

    url = f"https://drive.google.com/uc?id={GDRIVE_FILE_ID}"
    print(f"Downloading TrackNet weights to {WEIGHTS_PATH} ...")
    gdown.download(url, str(WEIGHTS_PATH), quiet=False)
    print("Done.")


if __name__ == "__main__":
    main()
