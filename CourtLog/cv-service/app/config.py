"""Application configuration."""

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
SESSIONS_DIR = DATA_DIR / "sessions"
MODELS_DIR = BASE_DIR / "models"
TRACKNET_WEIGHTS = MODELS_DIR / "tracknet.pth"

# Create runtime dirs
SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
MODELS_DIR.mkdir(parents=True, exist_ok=True)
