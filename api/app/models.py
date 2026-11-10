from decimal import Decimal
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field

class Input(BaseModel):
    model_config = ConfigDict(extra='forbid', allow_inf_nan=False)

class Componente(Input):
    id_cepa: int
    porcentaje: Decimal

class Vino(Input):
    nombre: str = Field(max_length=100)
    tipo: Literal['tinto','blanco','rosado','espumante']
    anada: int
    volumen_ml: int
    graduacion: Decimal
    precio: Decimal
    cuit_bodega: str = Field(max_length=11)
    composicion: list[Componente] = Field(max_length=100)
    maridajes: list[int] = Field(default_factory=list, max_length=100)

class Cliente(Input):
    nombre_razon_social: str = Field(max_length=150)
    tipo_doc: str = Field(max_length=20)
    nro_doc: str = Field(max_length=30)
    direccion: str = Field(max_length=200)
    localidad: str = Field(max_length=100)
    tipo_cliente: Literal['socio','distribuidor','exportador']
    zona_cobertura: str | None = Field(default=None,max_length=150)
    nro_habilitacion: str | None = Field(default=None,max_length=50)
    pais_destino_principal: str | None = Field(default=None,max_length=100)

class Renglon(Input):
    cod_vino: int
    cantidad: int

class Venta(Input):
    id_cliente: int
    id_sala: int
    renglones: list[Renglon] = Field(min_length=1,max_length=100)

class Transferencia(Input):
    id_sala: int

class Ingreso(Input):
    codigo_transportista: int
    cuit_bodega: str = Field(max_length=11)
