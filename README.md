# Bodegas del Atuel

Trabajo Práctico Integrador de la materia **Bases de Datos** — Ingeniería en Sistemas, UTN Facultad Regional San Rafael.

## Sobre el proyecto

**Bodegas del Atuel** es un sistema de gestión y distribución para una empresa vitivinícola.

La base de datos permitirá representar las principales operaciones del negocio, entre ellas:

- Gestión de bodegas y vinos.
- Cepas, composiciones y maridajes.
- Fincas, parcelas, lotes de uva y análisis de calidad.
- Localidades, salas de venta y empleados.
- Clientes y sus distintos tipos.
- Ventas y comprobantes.
- Ingresos de mercadería al depósito central.
- Transferencias de vinos hacia las salas de venta.
- Control de stock.

El proyecto busca aplicar los contenidos de la materia mediante una solución completa basada en PostgreSQL. En las etapas posteriores se incorporarán reglas de integridad, carga masiva de datos, consultas SQL, optimización, una API REST, un frontend y un despliegue en la nube.

Las reglas importantes del negocio estarán protegidas principalmente desde la base de datos, mediante claves, restricciones, funciones, procedimientos y triggers. De esta manera, la información se mantiene consistente independientemente de la aplicación que la utilice.

## Integrantes

- Renata
- Santiago

## Tecnologías

- PostgreSQL 14 o superior
- Docker y Docker Compose
- SQL
- Git y GitHub
- Python, API REST y frontend en etapas posteriores

## Estado actual

El proyecto se encuentra en la **Etapa 1 — Modelado**.

Actualmente se está trabajando en:

- Diagrama entidad-relación.
- Esquema relacional en tercera forma normal.
- Diccionario de datos.
- Justificación de las decisiones de diseño.
- Script inicial `001_esquema.sql`.
- Configuración de Docker y PostgreSQL.

El DER se encuentra en revisión, por lo que `001_esquema.sql` puede modificarse antes de considerarse definitivo.

## Estructura actual

```text
tpi-bodegas-del-atuel/
├── .env.example
├── .gitignore
├── compose.yaml
├── database/
│   └── migrations/
└── docs/
    ├── DER_Bodegas_del_Atuel.pdf
    ├── diccionario_de_datos.md
    └── pruebas-docker.md
```

## Configuración local

Crear un archivo `.env` en la raíz del repositorio, junto a `compose.yaml`.

Contenido de ejemplo:

```env
POSTGRES_DB=bodegas_atuel
POSTGRES_USER=postgres
POSTGRES_PASSWORD=CAMBIAR_ESTA_CONTRASENA
POSTGRES_PORT=5432
```

El archivo `.env` es local y no debe subirse al repositorio. El archivo `.env.example` sí se comparte como modelo.

## Comandos de Docker

Ejecutar los comandos desde la carpeta raíz del repositorio.

### Levantar PostgreSQL

```powershell
docker compose up -d
```

### Verificar el estado

```powershell
docker compose ps
```

### Consultar los logs

```powershell
docker compose logs db
```

Para seguir los logs en tiempo real:

```powershell
docker compose logs -f db
```

### Conectarse a PostgreSQL

```powershell
docker compose exec db psql -U postgres -d bodegas_atuel
```

Dentro de PostgreSQL:

```sql
SELECT current_database();
SELECT version();
\dt
```

Para salir:

```sql
\q
```

### Detener el entorno

```powershell
docker compose down
```

### Reiniciar la base desde cero

```powershell
docker compose down -v
docker compose up -d
```

El comando `docker compose down -v` elimina también el volumen local y todos los datos almacenados en él.

## Prueba del esquema

La prueba definitiva de `001_esquema.sql` se realizará cuando el equipo finalice la revisión del DER y actualice el modelo.

La documentación de las pruebas se encuentra en:

```text
docs/pruebas-docker.md
```

## Seguridad

No subir al repositorio:

- `.env`
- Contraseñas reales
- Tokens
- Cadenas de conexión privadas
- Backups con información sensible

Para verificar el estado del repositorio:

```powershell
git status
```

Para comprobar que `.env` está siendo ignorado:

```powershell
git check-ignore -v .env
```

## Próximos pasos

Después de finalizar la Etapa 1 se continuará con:

1. Restricciones y lógica en la base de datos.
2. Carga masiva de datos.
3. Índices y rendimiento.
4. Consultas SQL.
5. API REST.
6. Frontend.
7. Despliegue en la nube.
8. Documentación y defensa final.
