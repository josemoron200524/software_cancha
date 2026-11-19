import pytest
from fastapi import HTTPException
from pydantic import ValidationError
from app.schemas.persona_schema import (
    ClienteCreate,
    ClienteUpdate,
    EmpleadoCreate,
    EmpleadoUpdate,
)
from app.services.persona_service import PersonaService


class FakePersonaRepository:
    def __init__(self):
        self.correos = {"admin@cancha.com", "cliente@cancha.com"}
        self.clientes = {
            1: {
                "id_cliente": 1,
                "id_usuario": 3,
                "nombres": "Carlos",
                "apellidos": "Mendoza",
                "ci_nit": "1112223",
                "telefono": "70011223",
                "activo": True,
                "correo": "cliente@cancha.com",
            }
        }
        self.empleados = {
            1: {
                "id_empleado": 1,
                "id_usuario": 1,
                "nombres": "Ana",
                "apellidos": "Rojas",
                "ci": "1234567",
                "telefono": "71112222",
                "cargo": "Administrador General",
                "activo": True,
                "correo": "admin@cancha.com",
                "rol": "administrador",
            }
        }
        self.next_cliente_id = 2
        self.next_empleado_id = 2
        self.next_usuario_id = 10

    def existe_correo(self, correo: str) -> bool:
        return correo.lower() in {c.lower() for c in self.correos}

    # --- CLIENTES ---
    def listar_clientes(self, buscar: str | None = None, solo_activos: bool = True):
        lista = list(self.clientes.values())
        if solo_activos:
            lista = [c for c in lista if c["activo"]]
        if buscar:
            texto = buscar.strip().lower()
            lista = [
                c
                for c in lista
                if texto in c["nombres"].lower()
                or texto in c["apellidos"].lower()
                or texto in (c["ci_nit"] or "").lower()
                or texto in c["telefono"].lower()
            ]
        return lista

    def obtener_cliente_por_id(self, id_cliente: int):
        return self.clientes.get(id_cliente)

    def obtener_cliente_por_ci_nit(self, ci_nit: str):
        for c in self.clientes.values():
            if c["ci_nit"] == ci_nit:
                return c
        return None

    def crear_cliente(
        self, datos: dict, creado_por: int, password_hash: str | None = None
    ):
        id_usuario = None
        if datos.get("correo") and password_hash:
            id_usuario = self.next_usuario_id
            self.next_usuario_id += 1
            self.correos.add(datos["correo"])

        nuevo = {
            "id_cliente": self.next_cliente_id,
            "id_usuario": id_usuario,
            **datos,
            "password_hash": password_hash,
            "activo": True,
            "creado_por": creado_por,
        }
        self.clientes[self.next_cliente_id] = nuevo
        self.next_cliente_id += 1
        return nuevo

    def actualizar_cliente(self, id_cliente: int, datos: dict, modificado_por: int):
        self.clientes[id_cliente].update({**datos, "modificado_por": modificado_por})
        return self.clientes[id_cliente]

    def desactivar_cliente(self, id_cliente: int, modificado_por: int):
        self.clientes[id_cliente]["activo"] = False
        self.clientes[id_cliente]["modificado_por"] = modificado_por
        return self.clientes[id_cliente]

    # --- EMPLEADOS ---
    def listar_empleados(self, solo_activos: bool = True):
        lista = list(self.empleados.values())
        if solo_activos:
            return [e for e in lista if e["activo"]]
        return lista

    def obtener_empleado_por_id(self, id_empleado: int):
        return self.empleados.get(id_empleado)

    def obtener_empleado_por_ci(self, ci: str):
        for e in self.empleados.values():
            if e["ci"] == ci:
                return e
        return None

    def crear_empleado(self, datos: dict, password_hash: str, creado_por: int):
        id_usuario = self.next_usuario_id
        self.next_usuario_id += 1
        self.correos.add(datos["correo"])

        nuevo = {
            "id_empleado": self.next_empleado_id,
            "id_usuario": id_usuario,
            **datos,
            "password_hash": password_hash,
            "activo": True,
            "creado_por": creado_por,
        }
        self.empleados[self.next_empleado_id] = nuevo
        self.next_empleado_id += 1
        return nuevo

    def actualizar_empleado(self, id_empleado: int, datos: dict, modificado_por: int):
        self.empleados[id_empleado].update({**datos, "modificado_por": modificado_por})
        return self.empleados[id_empleado]

    def desactivar_empleado(self, id_empleado: int, modificado_por: int):
        self.empleados[id_empleado]["activo"] = False
        self.empleados[id_empleado]["modificado_por"] = modificado_por
        return self.empleados[id_empleado]


# ===================== PRUEBAS DE CLIENTES =====================
def test_crear_cliente_presencial_y_buscar():
    servicio = PersonaService(repo=FakePersonaRepository())
    creado = servicio.crear_cliente(
        ClienteCreate(
            nombres="  Juan  ",
            apellidos="  Pérez  ",
            ci_nit="7894561",
            telefono="71234567",
        ),
        id_usuario_actual=1,
    )

    assert creado["nombres"] == "Juan"
    assert creado["id_usuario"] is None
    assert len(servicio.listar_clientes(buscar="Jua")) == 1
    assert len(servicio.listar_clientes(buscar="7894561")) == 1


def test_crear_cliente_con_cuenta_portal_cifra_password():
    servicio = PersonaService(repo=FakePersonaRepository())
    creado = servicio.crear_cliente(
        ClienteCreate(
            nombres="Lucía",
            apellidos="Vargas",
            ci_nit="6543210",
            telefono="76543210",
            correo="  Lucia@Correo.COM ",
            password="ClaveSegura123",
        ),
        id_usuario_actual=1,
    )

    assert creado["id_usuario"] is not None
    assert creado["correo"] == "lucia@correo.com"
    assert creado["password_hash"] != "ClaveSegura123"


def test_crear_cliente_duplicados_lanzan_409():
    servicio = PersonaService(repo=FakePersonaRepository())

    with pytest.raises(HTTPException) as exc_ci:
        servicio.crear_cliente(
            ClienteCreate(
                nombres="Pedro",
                apellidos="Suárez",
                ci_nit="1112223",
                telefono="70009999",
            ),
            id_usuario_actual=1,
        )
    assert exc_ci.value.status_code == 409

    with pytest.raises(HTTPException) as exc_correo:
        servicio.crear_cliente(
            ClienteCreate(
                nombres="Pedro",
                apellidos="Suárez",
                ci_nit="9990001",
                telefono="70009999",
                correo="cliente@cancha.com",
                password="Password123",
            ),
            id_usuario_actual=1,
        )
    assert exc_correo.value.status_code == 409


def test_actualizar_y_desactivar_cliente():
    servicio = PersonaService(repo=FakePersonaRepository())
    actualizado = servicio.actualizar_cliente(
        1,
        ClienteUpdate(
            nombres="Carlos Eduardo",
            apellidos="Mendoza",
            ci_nit="1112223",
            telefono="79998888",
            activo=True,
        ),
        id_usuario_actual=1,
    )
    assert actualizado["nombres"] == "Carlos Eduardo"

    respuesta = servicio.desactivar_cliente(1, id_usuario_actual=1)
    assert respuesta["cliente"]["activo"] is False
    assert len(servicio.listar_clientes(solo_activos=True)) == 0


def test_cliente_inexistente_y_ci_duplicado_en_update():
    servicio = PersonaService(repo=FakePersonaRepository())

    with pytest.raises(HTTPException) as exc_404:
        servicio.obtener_cliente(999)
    assert exc_404.value.status_code == 404

    servicio.crear_cliente(
        ClienteCreate(
            nombres="Mario",
            apellidos="López",
            ci_nit="5554443",
            telefono="72223333",
        ),
        id_usuario_actual=1,
    )

    with pytest.raises(HTTPException) as exc_409:
        servicio.actualizar_cliente(
            2,
            ClienteUpdate(
                nombres="Mario",
                apellidos="López",
                ci_nit="1112223",
                telefono="72223333",
                activo=True,
            ),
            id_usuario_actual=1,
        )
    assert exc_409.value.status_code == 409


# ===================== PRUEBAS DE EMPLEADOS =====================
def test_crud_completo_empleados():
    servicio = PersonaService(repo=FakePersonaRepository())
    creado = servicio.crear_empleado(
        EmpleadoCreate(
            nombres="Luis",
            apellidos="Torrez",
            ci="8887776",
            telefono="73334444",
            cargo="Recepcionista Turno Tarde",
            rol="recepcionista",
            correo="luis@cancha.com",
            password="Recep123*",
        ),
        id_usuario_actual=1,
    )
    assert creado["id_empleado"] == 2
    assert creado["password_hash"] != "Recep123*"
    assert len(servicio.listar_empleados()) == 2

    actualizado = servicio.actualizar_empleado(
        2,
        EmpleadoUpdate(
            nombres="Luis Fernando",
            apellidos="Torrez",
            ci="8887776",
            telefono="73335555",
            cargo="Jefe de Recepción",
            rol="recepcionista",
            activo=True,
        ),
        id_usuario_actual=1,
    )
    assert actualizado["cargo"] == "Jefe de Recepción"

    desactivado = servicio.desactivar_empleado(2, id_usuario_actual=1)
    assert desactivado["empleado"]["activo"] is False
    assert len(servicio.listar_empleados(solo_activos=True)) == 1


def test_crear_empleado_duplicados_lanzan_409():
    servicio = PersonaService(repo=FakePersonaRepository())

    with pytest.raises(HTTPException) as exc_correo:
        servicio.crear_empleado(
            EmpleadoCreate(
                nombres="Sofía",
                apellidos="Cruz",
                ci="4443332",
                telefono="74445555",
                cargo="Recepcionista",
                rol="recepcionista",
                correo="admin@cancha.com",
                password="Password123",
            ),
            id_usuario_actual=1,
        )
    assert exc_correo.value.status_code == 409

    with pytest.raises(HTTPException) as exc_ci:
        servicio.crear_empleado(
            EmpleadoCreate(
                nombres="Sofía",
                apellidos="Cruz",
                ci="1234567",
                telefono="74445555",
                cargo="Recepcionista",
                rol="recepcionista",
                correo="sofia@cancha.com",
                password="Password123",
            ),
            id_usuario_actual=1,
        )
    assert exc_ci.value.status_code == 409


def test_empleado_inexistente_y_ci_duplicado_en_update():
    servicio = PersonaService(repo=FakePersonaRepository())

    with pytest.raises(HTTPException) as exc_404:
        servicio.obtener_empleado(999)
    assert exc_404.value.status_code == 404

    servicio.crear_empleado(
        EmpleadoCreate(
            nombres="Sofía",
            apellidos="Cruz",
            ci="4443332",
            telefono="74445555",
            cargo="Recepcionista",
            rol="recepcionista",
            correo="sofia@cancha.com",
            password="Password123",
        ),
        id_usuario_actual=1,
    )

    with pytest.raises(HTTPException) as exc_409:
        servicio.actualizar_empleado(
            2,
            EmpleadoUpdate(
                nombres="Sofía",
                apellidos="Cruz",
                ci="1234567",
                telefono="74445555",
                cargo="Recepcionista",
                rol="recepcionista",
                activo=True,
            ),
            id_usuario_actual=1,
        )
    assert exc_409.value.status_code == 409


def test_admin_no_puede_desactivarse_a_si_mismo():
    servicio = PersonaService(repo=FakePersonaRepository())

    with pytest.raises(HTTPException) as exc_upd:
        servicio.actualizar_empleado(
            1,
            EmpleadoUpdate(
                nombres="Ana",
                apellidos="Rojas",
                ci="1234567",
                telefono="71112222",
                cargo="Administrador General",
                rol="administrador",
                activo=False,
            ),
            id_usuario_actual=1,
        )
    assert exc_upd.value.status_code == 400

    with pytest.raises(HTTPException) as exc_del:
        servicio.desactivar_empleado(1, id_usuario_actual=1)
    assert exc_del.value.status_code == 400


# ===================== PRUEBAS DE SCHEMAS =====================
def test_schemas_persona_validaciones():
    with pytest.raises(ValidationError):
        ClienteCreate(
            nombres="Juan",
            apellidos="Pérez",
            telefono="71234567",
            correo="solo_correo@cancha.com",
        )

    with pytest.raises(ValidationError):
        ClienteCreate(
            nombres="Juan",
            apellidos="Pérez",
            telefono="71234567",
            password="SoloPassword123",
        )

    with pytest.raises(ValidationError):
        ClienteCreate(
            nombres="Juan",
            apellidos="Pérez",
            telefono="71234567",
            correo="correo_invalido",
            password="Password123",
        )

    with pytest.raises(ValidationError):
        EmpleadoCreate(
            nombres="Luis",
            apellidos="Torrez",
            ci="8887776",
            telefono="73334444",
            cargo="Recepcionista",
            rol="cliente",
            correo="luis@cancha.com",
            password="Password123",
        )