from fastapi import HTTPException, status
from app.repositories.catalogo_repository import CatalogoRepository
from app.schemas.catalogo_schema import (
    CanchaCreate,
    CanchaUpdate,
    HorarioCreate,
    HorarioUpdate,
    ServicioCreate,
    ServicioUpdate,
)


class CatalogoService:
    def __init__(self, repo: CatalogoRepository | None = None):
        self.repo = repo or CatalogoRepository()

    # ======================== CANCHAS ========================
    def listar_canchas(self, solo_disponibles: bool = False) -> list[dict]:
        return self.repo.listar_canchas(solo_disponibles=solo_disponibles)

    def obtener_cancha(self, id_cancha: int) -> dict:
        cancha = self.repo.obtener_cancha_por_id(id_cancha)
        if not cancha:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró la cancha con ID {id_cancha}.",
            )
        return cancha

    def crear_cancha(self, datos: CanchaCreate, id_usuario: int) -> dict:
        nombre_limpio = datos.nombre.strip()
        if self.repo.obtener_cancha_por_nombre(nombre_limpio):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe una cancha con el nombre '{nombre_limpio}'.",
            )

        payload = datos.model_dump()
        payload["nombre"] = nombre_limpio
        payload["tipo_superficie"] = datos.tipo_superficie.strip()
        return self.repo.crear_cancha(payload, creado_por=id_usuario)

    def actualizar_cancha(
        self, id_cancha: int, datos: CanchaUpdate, id_usuario: int
    ) -> dict:
        self.obtener_cancha(id_cancha)
        nombre_limpio = datos.nombre.strip()
        existente = self.repo.obtener_cancha_por_nombre(nombre_limpio)
        if existente and existente["id_cancha"] != id_cancha:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe otra cancha con el nombre '{nombre_limpio}'.",
            )

        payload = datos.model_dump()
        payload["nombre"] = nombre_limpio
        payload["tipo_superficie"] = datos.tipo_superficie.strip()
        return self.repo.actualizar_cancha(id_cancha, payload, modificado_por=id_usuario)

    def desactivar_cancha(self, id_cancha: int, id_usuario: int) -> dict:
        self.obtener_cancha(id_cancha)
        cancha = self.repo.desactivar_cancha(id_cancha, modificado_por=id_usuario)
        return {"mensaje": "Cancha marcada como inactiva.", "cancha": cancha}

    # ======================= SERVICIOS =======================
    def listar_servicios(self, solo_activos: bool = True) -> list[dict]:
        return self.repo.listar_servicios(solo_activos=solo_activos)

    def obtener_servicio(self, id_servicio: int) -> dict:
        servicio = self.repo.obtener_servicio_por_id(id_servicio)
        if not servicio:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el servicio con ID {id_servicio}.",
            )
        return servicio

    def crear_servicio(self, datos: ServicioCreate, id_usuario: int) -> dict:
        nombre_limpio = datos.nombre.strip()
        if self.repo.obtener_servicio_por_nombre(nombre_limpio):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe un servicio con el nombre '{nombre_limpio}'.",
            )

        payload = datos.model_dump()
        payload["nombre"] = nombre_limpio
        return self.repo.crear_servicio(payload, creado_por=id_usuario)

    def actualizar_servicio(
        self, id_servicio: int, datos: ServicioUpdate, id_usuario: int
    ) -> dict:
        self.obtener_servicio(id_servicio)
        nombre_limpio = datos.nombre.strip()
        existente = self.repo.obtener_servicio_por_nombre(nombre_limpio)
        if existente and existente["id_servicio"] != id_servicio:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe otro servicio con el nombre '{nombre_limpio}'.",
            )

        payload = datos.model_dump()
        payload["nombre"] = nombre_limpio
        return self.repo.actualizar_servicio(
            id_servicio, payload, modificado_por=id_usuario
        )

    def desactivar_servicio(self, id_servicio: int, id_usuario: int) -> dict:
        self.obtener_servicio(id_servicio)
        servicio = self.repo.desactivar_servicio(id_servicio, modificado_por=id_usuario)
        return {"mensaje": "Servicio desactivado correctamente.", "servicio": servicio}

    # =============== HORARIOS DE DISPONIBILIDAD ===============
    def listar_horarios_cancha(self, id_cancha: int) -> list[dict]:
        self.obtener_cancha(id_cancha)
        return self.repo.listar_horarios_por_cancha(id_cancha)

    def crear_horario(self, datos: HorarioCreate, id_usuario: int) -> dict:
        self.obtener_cancha(datos.id_cancha)
        if self.repo.obtener_horario_cancha_dia(datos.id_cancha, datos.dia_semana):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"La cancha {datos.id_cancha} ya tiene un horario para el día {datos.dia_semana}.",
            )

        return self.repo.crear_horario(datos.model_dump(), creado_por=id_usuario)

    def actualizar_horario(
        self, id_horario: int, datos: HorarioUpdate, id_usuario: int
    ) -> dict:
        horario = self.repo.obtener_horario_por_id(id_horario)
        if not horario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el horario con ID {id_horario}.",
            )
        return self.repo.actualizar_horario(
            id_horario, datos.model_dump(), modificado_por=id_usuario
        )

    def eliminar_horario(self, id_horario: int) -> dict:
        horario = self.repo.obtener_horario_por_id(id_horario)
        if not horario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el horario con ID {id_horario}.",
            )
        self.repo.eliminar_horario(id_horario)
        return {"mensaje": f"Horario {id_horario} eliminado correctamente."}