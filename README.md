# Bodegas del Atuel · TPI de Bases de Datos

Sistema de gestión, producción y distribución de una empresa vitivinícola ficticia, desarrollado para **Bases de Datos (3.º año, Ingeniería en Sistemas de Información, UTN Facultad Regional San Rafael, 2026)**.

**Estado documentado al 10/11/2026:** base de datos y lógica de negocio implementadas; carga masiva, consultas y optimización verificadas según las evidencias del repositorio; API REST local implementada con pruebas de integración. **No se encontró un frontend de H7 ni un despliegue público de H8 ni una entrega/defensa final H9 en `main`**. Esto no impide realizar una **demostración funcional local de H1–H6** usando PostgreSQL, Swagger y scripts (ver [demo/README.md](demo/README.md)). No se presenta esa demo como sustituto de los requisitos pendientes.

> **Nota de lectura:** algunos archivos históricos conservan frases como “pendiente”, escritas antes de que se integraran aportes. Para conocer el estado actual deben leerse las migraciones de `main` y las evidencias fechadas más recientes. La documentación antigua sirve para entender cómo evolucionó el proyecto, no siempre para describir su estado actual.

## 1. Equipo

Renata, Valentina, Santiago y Sol.

## 2. Qué resuelve el sistema

El modelo integra operaciones conectadas: fincas y parcelas producen lotes de uva que reciben análisis de calidad; las bodegas elaboran vinos con una composición porcentual por cepas y recomendaciones de maridaje; el depósito central recibe botellas mediante ingresos y las distribuye a salas mediante transferencias; los clientes (socios, distribuidores y exportadores) compran en salas, generando comprobantes y renglones con precio y descuento históricos.

La **base de datos** es la fuente de las reglas de negocio: la API no debe recalcular descuentos, montos ni stock. Las claves y restricciones validan datos simples; funciones y triggers protegen coherencia; procedimientos almacenados ejecutan movimientos transaccionales con bloqueos apropiados.

## 3. Tecnologías y arquitectura

- **Datos:** PostgreSQL 16 en Docker, SQL y PL/pgSQL. Es compatible con la consigna de PostgreSQL 14 o superior.
- **Integridad:** PK, FK, UNIQUE, CHECK, NOT NULL, DEFAULT, ENUM y DOMAIN; funciones, triggers, constraint triggers diferidos y procedimientos `SECURITY DEFINER`.
- **Carga sintética:** Python, Faker `es_AR`, CSV de catálogos y `psycopg2` en lotes.
- **API local:** FastAPI, Pydantic, `psycopg` 3, pool de conexiones, SQL explícito y parametrizado; **sin ORM**.
- **Infraestructura local:** Docker Compose, Swagger/OpenAPI y colección Postman.
- **Pruebas:** SQL en PostgreSQL, evidencia de concurrencia, validador Node/PGlite de apoyo y 14 pruebas de integración definidas para H6.

```text
Swagger / Postman / script de demostración
                  |
                  v
             API FastAPI
          (api/app/main.py)
                  |
                  v
           SQL directo / DAL
           (api/app/dal.py)
                  |
                  v
             PostgreSQL
    tablas + FK/CHECK + funciones +
    triggers + procedimientos + roles
```

**El esquema y los datos de la API H6 no son automáticamente los datos masivos de H3.** El inicializador H6 crea una base aislada `bodegas_api_h6` y le instala las migraciones. La base de carga H3 se trabaja por separado.

## 4. Estado por hito (con evidencias)

| Hito | Estado verificable en repositorio | Evidencia principal |
|---|---|---|
| **H1 · Modelo** | DER actualizado, 29 tablas, diccionario y normalización documentados | [`docs/der/`](docs/der/), [`docs/modelo_relacional_vigente.md`](docs/modelo_relacional_vigente.md), [`docs/normalizacion_3fn.md`](docs/normalizacion_3fn.md) |
| **H2 · Integridad** | RN-01 a RN-15 trazadas; migraciones y pruebas en PostgreSQL 16.15 según registros | [`docs/revision_modelo_y_cobertura.md`](docs/revision_modelo_y_cobertura.md), [`docs/evidencias/cierre_h2_base_nueva.txt`](docs/evidencias/cierre_h2_base_nueva.txt) |
| **H3 · Carga** | 20.000 clientes, 150.000 comprobantes, 500.000 renglones y restauración validada, según reportes | [`docs/evidencias/h3_completa.json`](docs/evidencias/h3_completa.json), [`docs/evidencias/h3_validacion_restaurada.txt`](docs/evidencias/h3_validacion_restaurada.txt) |
| **H4 · Índices** | Índices implementados y comparados con `EXPLAIN (ANALYZE, BUFFERS)` en PostgreSQL 16.15 | [`docs/rendimiento.md`](docs/rendimiento.md), [`database/migrations/008_indices.sql`](database/migrations/008_indices.sql) |
| **H5 · SQL** | S1–S12, I1–I6, U1–U6 y D1–D6, con salidas de ejecución documentadas | [`scripts/consultas_s1_s8.sql`](scripts/consultas_s1_s8.sql), [`consultas/`](consultas/), [`docs/evidencias/`](docs/evidencias/) |
| **H6 · API** | API REST y 14 pruebas de integración definidas, con comandos para correrlas localmente | [`api/`](api/), [`docs/H6_API.md`](docs/H6_API.md), [`api/tests/test_api.py`](api/tests/test_api.py) |
| **H7 · Front** | **No encontrado en `main`** | Pendiente de incorporar o evidenciar |
| **H8 · Nube** | **No hay despliegue público verificable en `main`** | Pendiente de desplegar/evidenciar |
| **H9 · Entrega** | Material técnico disponible, pero **sin defensa final acreditada** | Pendiente según instrucciones docentes |

Los estados H1–H6 reflejan **archivos y evidencia registrada**, no una nueva ejecución integral independiente hecha para este README.

### Datos y rendimiento documentados

La carga H3 reporta **29 tablas pobladas**, 300 vinos, 15 salas, 20.000 clientes, 150.000 comprobantes y 500.000 renglones. El dump se restauró y validó según `h3_validacion_restaurada.txt`.

En H4 se compararon consultas S4, S5 y S8, con tres repeticiones por escenario en PostgreSQL 16.15 y vinos frecuentes/poco frecuentes. Por ejemplo, S4 con vino poco frecuente pasó de **25,443 ms a 0,895 ms** (medianas de ese banco de prueba). Los resultados no garantizan mejoras universales y un índice también puede encarecer escrituras. Detalles: [`docs/rendimiento.md`](docs/rendimiento.md).

## 5. Reglas esenciales y archivos donde se implementan

| Tema | Archivo |
|---|---|
| Tablas, relaciones, jerarquía de clientes, parcela débil, ENUM, DOMAIN | [`001_esquema.sql`](database/migrations/001_esquema.sql) |
| Positividad, unicidad, rangos, permisos y descuentos almacenados | [`002_constraints.sql`](database/migrations/002_constraints.sql) |
| Tasa de descuento, total de comprobante, stock y antigüedad | [`003_funciones.sql`](database/migrations/003_funciones.sql) |
| Terminar/procesar ingresos y transferencias, movimientos de stock | [`004_procedimientos.sql`](database/migrations/004_procedimientos.sql) |
| Descuento base, composición 100 %, auditoría, venta/stock, estados y subtipo | [`005_triggers.sql`](database/migrations/005_triggers.sql) |
| Stock global, exportadores y resumen de comprobantes | [`006_vistas.sql`](database/migrations/006_vistas.sql) |
| Roles, `REVOKE`, `GRANT`, permisos por columna y propietarios técnicos | [`007_roles.sql`](database/migrations/007_roles.sql) |
| Índices compuestos, parciales y `INCLUDE` | [`008_indices.sql`](database/migrations/008_indices.sql) |
| Rol de catálogo para H6 | [`009_api_catalogos.sql`](database/migrations/009_api_catalogos.sql) |
| Concurrencia de la última botella con/sin bloqueo | [`docs/concurrencia_ventas.md`](docs/concurrencia_ventas.md) |

La jerarquía `cliente` + tres subtipos es **total y disjunta**, controlada por triggers diferidos. La composición de cada vino debe sumar exactamente 100 % al verificar la transacción. Un ingreso/transferencia debe pasar por `en_confeccion → terminado → procesado`; sólo procesar modifica inventario.

**Límites conocidos:** los triggers de venta calculan importes en **INSERT**, no garantizan recálculo automático general para `UPDATE/DELETE` administrativos; `cliente.localidad` es texto sin FK; el historial de auditoría de un vino puede eliminarse por `ON DELETE CASCADE` si el vino se borra legalmente; la consulta de trazabilidad devuelve lotes **candidatos**, no su origen físico demostrado. Ver [`docs/revision_modelo_y_cobertura.md`](docs/revision_modelo_y_cobertura.md).

## 6. Estructura del proyecto

```text
.
├── .env.example                 # Variables PostgreSQL; agregar secretos H6 en .env local
├── compose.yaml                 # PostgreSQL 16
├── compose.h6.yaml              # api-init, api y api-test
├── database/
│   ├── migrations/              # 001–009, más script auxiliar 004_datos_prueba.sql
│   ├── tests/                   # Pruebas SQL de integridad y operaciones
│   └── benchmarks/              # Fixtures y EXPLAIN
├── api/
│   ├── app/                     # FastAPI, DAL, modelos y pool
│   ├── tests/test_api.py        # 14 pruebas de integración
│   └── bootstrap.py             # Instalación de base H6 aislada
├── consultas/                   # INSERT, UPDATE, DELETE y SELECT avanzadas
├── scripts/                     # Consultas S1–S8 y controles
├── data/                        # CSV de catálogos
├── etapa3_carga.py              # Generador masivo H3
├── exportar_h3.py               # Exportación de dump
├── tools/validacion_sql/        # Validación auxiliar
├── docs/                        # Modelo, informes y evidencias
└── demo/                        # Ejemplo local integral (archivos propuestos)
```

## 7. Arranque de la API en entorno local (Windows/PowerShell)

### Preparación

Instalar Docker Desktop y usar una copia local del repositorio. En la raíz, crear `.env` a partir de `.env.example` sin subirlo a Git. Configurar `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT` y agregar al menos:

```dotenv
API_DB_NAME=bodegas_api_h6
API_DB_USER=bodegas_api_h6_login
API_DB_PASSWORD=CAMBIAR_CLAVE_API_LOCAL
API_TEST_PASSWORD=CAMBIAR_CLAVE_TEST_LOCAL_DIFERENTE
API_PORT=8000
```

**Importante:** el archivo `.env.h6.example` mencionado en algunos documentos antiguos **no está presente en el árbol `main` revisado**; las variables necesarias aparecen en `compose.h6.yaml` y en el ejemplo anterior.

### Arrancar y comprobar

```powershell
docker compose -f compose.yaml -f compose.h6.yaml up --build -d api
docker compose -f compose.yaml -f compose.h6.yaml ps
Invoke-RestMethod http://localhost:8000/salud
Start-Process http://localhost:8000/docs
```

- `GET /salud`: confirma la conexión y el usuario no administrativo.
- `http://localhost:8000/docs`: Swagger UI, interfaz disponible para probar la API aunque aún no haya frontend propio.
- `http://localhost:8000/openapi.json`: contrato OpenAPI.
- [`docs/h6_postman_collection.json`](docs/h6_postman_collection.json): colección Postman.

**Corrección propuesta para instalaciones nuevas:** en la versión de `api/bootstrap.py` analizada, el `GRANT rol_operador_ventas` ocurre antes de que `007_roles.sql` cree ese rol. Para un clúster vacío, puede fallar. Hay un `api/bootstrap.py` corregido incluido en el paquete de actualización adjunto a esta propuesta. Aplicar ese archivo **antes** de crear una base H6 nueva. No sobrescribir una base H6 parcialmente inicializada ni usar el bootstrap contra H3.

### Ejecutar pruebas de integración de H6

```powershell
docker compose -f compose.yaml -f compose.h6.yaml --profile test run --rm api-test
```

La prueba usa `bodegas_api_h6_test`, **independiente** de `bodegas_api_h6` y de la base H3. El código define 14 pruebas para CRUD, pagos/stock, reglas diferidas, estados, seguridad, consultas y reportes. Guardar la salida real de la ejecución para la defensa.

## 8. Demostración local completa sin frontend ni nube

**[Abrir el instructivo de demostración](demo/README.md)**. El recorrido propuesto se ejecuta sobre una base H6 aislada, con `demo/seed.sql` y `demo/demo_api.ps1`:

1. Crear bodega, vino Malbec de composición 100 %, finca, parcela, lote, análisis, sala, cliente socio, maridaje y transportista.
2. Recibir **30 botellas** mediante ingreso en confección, terminado y procesado.
3. Transferir **12 botellas** a una sala: depósito queda en 18 y sala en 12.
4. Vender **2 botellas** a $10.000 cada una a un socio: bruto $20.000, descuento del 10 % $2.000, total **$18.000**; stock de sala queda en 10.
5. Intentar vender **999 botellas**: la base impide el stock insuficiente y la API responde **409**, sin comprobante parcial.
6. Cambiar el precio actual a $12.000: el trigger audita el cambio, pero el comprobante ya generado conserva **$10.000** por botella.
7. Consultar el vino, el stock y los reportes en Swagger. Mostrar `SELECT ... FOR UPDATE`, `ROLLBACK`, `EXPLAIN` y vistas desde psql para explicar el trabajo académico.

El ejemplo es **un escenario reproducible propuesto**, construido a partir del SQL/API revisados. Requiere ejecutarse en la computadora del equipo para verificar el recorrido de punta a punta: **no se afirma que se haya ejecutado aquí con Docker**.

## 9. Carga masiva H3 y consultas H5

H3 es una base aparte. **No correr el generador sobre la base H6 de la demostración.** Guía detallada: [`docs/H3_EJECUCION.md`](docs/H3_EJECUCION.md). Los reportes ya guardados muestran la ejecución del perfil completo y restauración.

Para H5, las consultas se encuentran en [`scripts/consultas_s1_s8.sql`](scripts/consultas_s1_s8.sql) y [`consultas/`](consultas/). Muchos ejercicios de INSERT/UPDATE/DELETE emplean `SAVEPOINT` y `ROLLBACK` para evitar cambios persistentes. Revisar parámetros de `psql` y ejecutar sobre una **base de práctica**, no sobre el único conjunto de datos del equipo.

## 10. Seguridad y operaciones

- Mantener `.env`, claves, tokens y dumps sensibles fuera de Git.
- Usar el login de la API con privilegios mínimos; no conectarla como `postgres`.
- SQL parametrizado; las operaciones de negocio se ejecutan desde funciones/procedimientos/triggers en PostgreSQL.
- Guardar evidencias de las pruebas y respaldos; H3 incluye restauración verificada de un dump, **lo cual no acredita aún una estrategia de backup en producción**.
- No ejecutar `docker compose down -v` si se desean conservar datos: borra volúmenes.

## 11. Trabajo pendiente para cierre del TPI

- **H7:** desarrollar una interfaz propia que consuma la API (no necesaria para usar Swagger, pero exigida por la consigna).
- **H8:** desplegar base, API y frontend, probar seguridad, accesos, backup/restauración y documentar URL pública.
- **H9:** informe de cierre, video o demo según pida la cátedra, README definitivo y defensa grupal/individual.

**Conclusión:** H1–H6 permiten una defensa técnica local extensa y verificable. Sin H7–H9 se puede mostrar el núcleo del trabajo, pero no corresponde afirmar que se cumplió la totalidad de las nueve etapas del enunciado.
