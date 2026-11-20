from fastapi import HTTPException, status
from app.core.security import hash_password
from app.repositories.persona_repository import PersonaRepository
from app.schemas.persona_schema import (
    ClienteCreate,
    ClienteHabilitarPortal,
    ClienteUpdate,
    EmpleadoCreate,
    EmpleadoUpdate,
)


class PersonaService:
    def __init__(self, repo: PersonaRepository | None = None):
        self.repo = repo or PersonaRepository()

    # ======================== CLIENTES ========================
    def listar_clientes(
        self, buscar: str | None = None, solo_activos: bool = True
    ) -> list[dict]:
        return self.repo.listar_clientes(buscar=buscar, solo_activos=solo_activos)

    def obtener_cliente(self, id_cliente: int) -> dict:
        cliente = self.repo.obtener_cliente_por_id(id_cliente)
        if not cliente:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el cliente con ID {id_cliente}.",
            )
        return cliente

    def crear_cliente(self, datos: ClienteCreate, id_usuario_actual: int) -> dict:
        ci_limpio = datos.ci_nit.strip() if datos.ci_nit else None
        if ci_limpio and self.repo.obtener_cliente_por_ci_nit(ci_limpio):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe un cliente registrado con el CI/NIT '{ci_limpio}'.",
            )

        password_cifrado = None
        if datos.correo:
            if self.repo.existe_correo(datos.correo):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Ya existe una cuenta registrada con el correo '{datos.correo}'.",
                )
            password_cifrado = hash_password(datos.password)

        payload = {
            "nombres": datos.nombres.strip(),
            "apellidos": datos.apellidos.strip(),
            "ci_nit": ci_limpio,
            "telefono": datos.telefono.strip(),
            "correo": datos.correo,
        }
        return self.repo.crear_cliente(
            payload, creado_por=id_usuario_actual, password_hash=password_cifrado
        )

    def actualizar_cliente(
        self, id_cliente: int, datos: ClienteUpdate, id_usuario_actual: int
    ) -> dict:
        self.obtener_cliente(id_cliente)
        ci_limpio = datos.ci_nit.strip() if datos.ci_nit else None
        if ci_limpio:
            existente = self.repo.obtener_cliente_por_ci_nit(ci_limpio)
            if existente and existente["id_cliente"] != id_cliente:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Ya existe otro cliente con el CI/NIT '{ci_limpio}'.",
                )

        payload = {
            "nombres": datos.nombres.strip(),
            "apellidos": datos.apellidos.strip(),
            "ci_nit": ci_limpio,
            "telefono": datos.telefono.strip(),
            "activo": datos.activo,
        }
        return self.repo.actualizar_cliente(
            id_cliente, payload, modificado_por=id_usuario_actual
        )

    def habilitar_portal_cliente(
        self,
        id_cliente: int,
        datos: ClienteHabilitarPortal,
        id_usuario_actual: int,
    ) -> dict:
        cliente = self.obtener_cliente(id_cliente)
        if not cliente["activo"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se puede habilitar acceso al portal a un cliente inactivo.",
            )
        if cliente["id_usuario"] is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Este cliente ya cuenta con acceso al portal.",
            )
        if self.repo.existe_correo(datos.correo):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe una cuenta registrada con el correo '{datos.correo}'.",
            )

        password_cifrado = hash_password(datos.password)
        return self.repo.habilitar_portal_cliente(
            id_cliente=id_cliente,
            correo=datos.correo,
            password_hash=password_cifrado,
            modificado_por=id_usuario_actual,
        )

    def desactivar_cliente(self, id_cliente: int, id_usuario_actual: int) -> dict:
        self.obtener_cliente(id_cliente)
        cliente = self.repo.desactivar_cliente(
            id_cliente, modificado_por=id_usuario_actual
        )
        return {"mensaje": "Cliente desactivado correctamente.", "cliente": cliente}

    # ======================== EMPLEADOS ========================
    def listar_empleados(self, solo_activos: bool = True) -> list[dict]:
        return self.repo.listar_empleados(solo_activos=solo_activos)

    def obtener_empleado(self, id_empleado: int) -> dict:
        empleado = self.repo.obtener_empleado_por_id(id_empleado)
        if not empleado:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No se encontró el empleado con ID {id_empleado}.",
            )
        return empleado

    def crear_empleado(self, datos: EmpleadoCreate, id_usuario_actual: int) -> dict:
        ci_limpio = datos.ci.strip()
        if self.repo.existe_correo(datos.correo):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe una cuenta registrada con el correo '{datos.correo}'.",
            )
        if self.repo.obtener_empleado_por_ci(ci_limpio):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe un empleado registrado con el CI '{ci_limpio}'.",
            )

        payload = {
            "nombres": datos.nombres.strip(),
            "apellidos": datos.apellidos.strip(),
            "ci": ci_limpio,
            "telefono": datos.telefono.strip(),
            "cargo": datos.cargo.strip(),
            "rol": datos.rol,
            "correo": datos.correo,
        }
        password_cifrado = hash_password(datos.password)
        return self.repo.crear_empleado(
            payload, password_hash=password_cifrado, creado_por=id_usuario_actual
        )

    def actualizar_empleado(
        self, id_empleado: int, datos: EmpleadoUpdate, id_usuario_actual: int
    ) -> dict:
        empleado_actual = self.obtener_empleado(id_empleado)

        if empleado_actual["id_usuario"] == id_usuario_actual and not datos.activo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puedes desactivar tu propia cuenta de administrador.",
            )

        ci_limpio = datos.ci.strip()
        existente = self.repo.obtener_empleado_por_ci(ci_limpio)
        if existente and existente["id_empleado"] != id_empleado:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ya existe otro empleado registrado con el CI '{ci_limpio}'.",
            )

        payload = {
            "nombres": datos.nombres.strip(),
            "apellidos": datos.apellidos.strip(),
            "ci": ci_limpio,
            "telefono": datos.telefono.strip(),
            "cargo": datos.cargo.strip(),
            "rol": datos.rol,
            "activo": datos.activo,
        }
        return self.repo.actualizar_empleado(
            id_empleado, payload, modificado_por=id_usuario_actual
        )

    def desactivar_empleado(self, id_empleado: int, id_usuario_actual: int) -> dict:
        empleado_actual = self.obtener_empleado(id_empleado)
        if empleado_actual["id_usuario"] == id_usuario_actual:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puedes desactivar tu propia cuenta de administrador.",
            )

        empleado = self.repo.desactivar_empleado(
            id_empleado, modificado_por=id_usuario_actual
        )
        return {"mensaje": "Empleado desactivado correctamente.", "empleado": empleado}