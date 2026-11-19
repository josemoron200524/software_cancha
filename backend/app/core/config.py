import os
from pathlib import Path
from dotenv import load_dotenv

# Ubica la carpeta raíz software_cancha/ subiendo 3 niveles desde este archivo
BASE_DIR = Path(__file__).resolve().parents[3]
load_dotenv(BASE_DIR / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")
JWT_SECRET = os.getenv("JWT_SECRET")
PORT = int(os.getenv("PORT", "3000"))