from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.core.database import get_db_connection
from app.routes.auth_routes import router as auth_router
from app.routes.catalogo_routes import router as catalogo_router

app = FastAPI(
    title="API Sistema de Reservas de Canchas Deportivas",
    description="Backend en capas con FastAPI y PostgreSQL (Neon)",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(catalogo_router)


@app.get("/", tags=["Sistema"])
def inicio():
    return {"mensaje": "API de Reservas de Canchas funcionando correctamente"}


@app.get("/health/db", tags=["Sistema"])
def verificar_base_de_datos():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) AS total_canchas FROM canchas;")
                resultado = cur.fetchone()
        return {
            "estado": "conectado",
            "base_de_datos": "Neon PostgreSQL",
            "total_canchas": resultado["total_canchas"],
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al conectar con la base de datos: {str(e)}",
        )