# H6 — API REST para Bodegas del Atuel

La API expone operaciones del sistema mediante FastAPI y PostgreSQL. El controlador de inventario, los importes de venta, los descuentos y la transición de documentos siguen siendo responsabilidad de las reglas existentes en la base. Las rutas agrupan sus escrituras en transacciones: un error SQL o una validación diferida revierte la operación completa.

## Ejecución local con Docker Compose

1. Copiar el contenido del paquete H6 a la raíz del repositorio. Conservar el `.env` existente y agregarle las variables que aparecen en `.env.h6.example`, reemplazando ambas claves por secretos locales distintos.
2. Incorporar `database/migrations/009_api_catalogos.sql` después de las migraciones 001–008.
3. En PowerShell, desde la raíz del repositorio:

```powershell
docker compose -f compose.yaml -f compose.h6.yaml up --build -d api
docker compose -f compose.yaml -f compose.h6.yaml ps
Invoke-RestMethod http://localhost:8000/salud
```

La primera ejecución crea una base aislada `bodegas_api_h6`, instala 001–009 y crea un usuario de login de permisos mínimos. La aplicación escucha solo en `127.0.0.1`. La API requiere las variables administrativas existentes del servicio PostgreSQL para preparar esa base; sus credenciales no se pasan al contenedor de la aplicación. `api-init` se ejecuta como tarea de inicialización y verifica el marcador de esquema en ejecuciones posteriores.

Para correr las pruebas de integración en otra base desechable:

```powershell
docker compose -f compose.yaml -f compose.h6.yaml --profile test run --rm api-test
```

La suite tiene 14 pruebas de integración sobre PostgreSQL real: CRUD de vinos/clientes, ventas con y sin stock, errores de precio/FK/composición, estado inválido de ingreso y transferencia, ciclo de procesamiento de transferencia, permisos del login, paginación, filtro parametrizado y endpoints de informes. El contenedor de pruebas usa `bodegas_api_h6_test`, una base de integración desechable; no elimina automáticamente la base al terminar. No apuntar `API_DB_NAME` a una base con datos del proyecto ni reutilizar credenciales de producción.

## Contrato HTTP

FastAPI publica OpenAPI y Swagger UI en `/openapi.json` y `/docs`. La colección `h6_postman_collection.json` usa `{{baseUrl}}` con valor predeterminado `http://localhost:8000`.

| Método y ruta | Operación |
|---|---|
| `GET /salud` | Estado de conexión y usuario efectivo |
| `GET /vinos` | Listado paginado; filtros opcionales `tipo`, `cepa`, `bodega`, `anada`, `q`, `limit`, `offset` |
| `GET /vinos/{cod}` | Vino, composición, maridajes y stock agregado |
| `POST /vinos`, `PUT /vinos/{cod}`, `DELETE /vinos/{cod}` | Alta, reemplazo completo y baja de vinos |
| `GET /clientes`, `GET /clientes/{cod}` | Clientes paginados o por ID |
| `POST /clientes`, `PUT /clientes/{cod}`, `DELETE /clientes/{cod}` | Alta/cambio con subtipo y baja de clientes |
| `POST /comprobantes`, `GET /comprobantes/{nro}` | Registrar venta y consultar comprobante con renglones |
| `POST /ingresos`, `GET /ingresos/{cod}` | Crear y consultar ingresos |
| `POST /ingresos/{cod}/renglones` | Agregar renglón en confección |
| `POST /ingresos/{cod}/terminar`, `POST /ingresos/{cod}/procesar` | Cierre y procesamiento por procedimiento almacenado |
| `POST /transferencias`, `GET /transferencias/{nro}` | Crear y consultar transferencias |
| `POST /transferencias/{nro}/renglones` | Agregar renglón en confección |
| `POST /transferencias/{nro}/terminar`, `POST /transferencias/{nro}/procesar` | Cierre y movimiento de stock por procedimiento |
| `GET /reportes/top-vinos` | Vinos con más unidades vendidas |
| `GET /reportes/ventas-por-sala` | Ventas netas por sala, con fecha de referencia y paginación |
| `GET /reportes/vinos-sin-stock?sala=…` | Vinos con stock central y sin stock en la sala indicada |
| `GET /reportes/transportista-activo` | Transportista con más ingresos en la ventana mensual |
| `GET /reportes/trazabilidad/{cod}` | Lotes candidatos por cepa y bodega, con limitación del modelo aclarada en la respuesta |

Las listas admiten `limit` entre 1 y 100 y `offset` desde 0. `PUT` reemplaza el recurso y sus asociaciones; en clientes, un exportador con permisos no puede cambiar de subtipo desde esta API. Los errores incluyen `sqlstate` para los casos de base reconocidos. Claves o restricciones únicas/FK devuelven 409; restricciones de negocio 422; falta de recurso 404; permisos insuficientes 403; errores de conexión/contención temporal 503 con `Retry-After`.

## Seguridad y límites

- La aplicación usa psycopg 3 y parámetros SQL para los valores. Los nombres de tabla/procedimiento variables se obtienen únicamente de listas internas cerradas.
- `rol_api_catalogos` concede escritura acotada de catálogos. El login hereda `rol_operador_ventas` para ventas e ingreso/transferencia, sin permisos directos de escritura en stock ni en los estados.
- La conexión del pool tiene `statement_timeout`, `lock_timeout`, tamaño máximo de cinco conexiones y verifica que el login no sea superusuario, creador de roles/bases, bypass-RLS ni propietario de tablas.
- La base que crea H6 contiene el esquema y datos de catálogos iniciales vacíos de producción; no importa automáticamente datos H3.
- El reporte de trazabilidad solo encuentra lotes candidatos compatibles con cepa y bodega: el modelo actual no enlaza un lote con una partida concreta de vino.
- La prueba de concurrencia multisesión de H1/H2 permanece en su evidencia PostgreSQL. H6 prueba la transacción de transferencia y sus errores sobre una base de integración.

