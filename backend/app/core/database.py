import psycopg
from psycopg.rows import dict_row
from app.core.config import DATABASE_URL


def get_db_connection():
    if not DATABASE_URL:
        raise ValueError("No se encontró DATABASE_URL en el archivo .env")
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)