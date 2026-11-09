# H3: carga sintetica, validacion y mediciones

Esta version sustituye el generador incompleto de niveles 0–3. Conserva semilla 42,
Faker es_AR, fecha de referencia 2025-01-15, los CSV existentes y la correspondencia
entre bodega del ingreso y vinos. El plan de abastecimiento se calcula a partir de
las ventas antes de insertar filas. El proyecto debe tener las migraciones 001–008
actuales de main (incluida integridad de subtipos de clientes).

## Ejecucion inicial en Windows

Desde la raiz del repositorio, con Docker activo y la base vacia bodegas_carga_h3
que ya tiene las ocho migraciones:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-h3.txt
$env:DB_NAME = "bodegas_carga_h3"
$env:DB_HOST = "127.0.0.1"
$env:DB_PORT = "5433"
$env:DB_USER = "postgres"
.\.venv\Scripts\python.exe etapa3_carga.py --perfil prueba --comparar --reporte docs/evidencias/h3_prueba.json
```

La clave se solicita sin mostrarla. No es necesario escribirla en el script,
versionarla ni compartir .env. DB_PASSWORD, si existe, tiene prioridad sobre
la solicitud interactiva. El script no lee automaticamente el archivo .env.

Perfil prueba: 60 clientes, 200 comprobantes, 700 renglones, 20 vinos y 3 salas.
Las 29 tablas quedan pobladas. Se rechazan bases con datos; no hay TRUNCATE,
DROP ni opcion que borre datos existentes. El nombre debe empezar por
bodegas_carga_h3. Comprobar el nombre es una proteccion de uso, no una frontera
contra un administrador malicioso.

## Carga completa

No ejecutar sobre la base que ya contiene la prueba. Crear una segunda base
bodegas_carga_h3_completa e instalar las mismas ocho migraciones, como se hizo
para la primera. No ejecutar 004_datos_prueba.sql.

```powershell
$env:DB_NAME = "bodegas_carga_h3_completa"
.\.venv\Scripts\python.exe etapa3_carga.py --perfil completo --metodo lotes --reporte docs/evidencias/h3_completa.json
```

Volumen exacto: 20.000 clientes, 150.000 comprobantes y 500.000 renglones.
Por lo tanto tres tablas superan 10.000 y al menos una supera 100.000.
Hay 300 vinos, 15 salas, 10 bodegas, 50 fincas y 300 lotes; los demas conteos
se guardan en el JSON. Todas las tablas, incluida auditoria_precio, tienen filas.

La carga completa mantiene triggers por fila: puede tardar. No se atribuye a COPY
un rendimiento que no se midio: el metodo por lotes es execute_values de
psycopg2, en paginas de 1.000 filas. Una sola transaccion evita carga parcial.
No cerrar la consola mientras se ejecuta. Un fallo SQL hace rollback; las
secuencias PostgreSQL pueden avanzar aun si se revierte una transaccion.

## Orden y stock

1. Catalogos CSV -> bodegas/transportistas/localidades -> salas, empleados.
2. Fincas -> parcelas -> lotes -> analisis.
3. Vinos -> composiciones 60/40 (o 100 si hay una sola cepa del tipo) -> maridajes.
4. Clientes -> subtipo correcto -> permisos. Validacion diferida forzada.
5. Un cambio de precio real genera auditoria mediante el trigger.
6. Ingresos y detalles de su bodega -> terminar/procesar con procedimientos.
7. Transferencias y detalles -> terminar/procesar con procedimientos.
8. Comprobantes -> detalles. Los triggers fijan precios, descuentos, totales y stock.
9. Controles, rehabilitacion del trigger de fecha, ajuste de secuencias, ANALYZE, COMMIT.

Cada ingreso abastece demanda calculada mas reservas: al final hay 100 botellas
por vino en deposito y 20 por combinacion sala/vino. No se precarga stock final.
Las tres tasas base se aplican mediante el trigger; no se ejecuta U6 durante esta
carga. Hay exportadores con 1–5 permisos para poder demostrar U6 despues. Los
permisos no son una autorizacion de ventas aplicada por este generador.
Los datos de personas, bodegas, transportistas, CUIT (solo formato), documentos,
movimientos y precios son sinteticos. Los correos usan example.invalid.

Los CSV suministrados aportan cepas, departamentos y maridajes. localidades.csv
externaliza el catalogo reducido que ya usaba el proyecto. No es un padron oficial
ni exhaustivo de codigos postales. Sus nombres deben revisarse si la consigna exige
otra fuente. Los IDs de CSV son referencias de catalogo: las claves de la base
se asignan por orden de filas, y las relaciones usan esas mismas claves.
La zona_vitivinicola se conserva en CSV, pero no se inventa una columna SQL nueva.

## Fechas historicas y triggers

La fecha de referencia, semilla y versiones de dependencias son fijas. Ventas:
ultimo ano previo a la referencia; clientes dados de alta antes; vinos de anada
anterior; ingreso 400 dias antes y transferencia 390 dias antes. Campanas y analisis
son anteriores a la fecha de referencia.

En la base exclusiva se bloquean las 29 tablas contra otras escrituras. Se exige
que todos los triggers esten activos en modo normal. Solo se suspende
trg_proteger_fecha_transferencia para insertar su fecha historica. Su reactivacion,
las validaciones y las inserciones estan dentro de la misma transaccion; si falla
la transaccion, tambien se revierte la suspension. NO se usa DISABLE TRIGGER ALL,
DISABLE TRIGGER USER ni session_replication_role. FK/CHECK/UNIQUE/NOT NULL y todos
los otros triggers permanecen activos. El rol que ejecuta debe poder administrar
ese trigger; se usa postgres solamente en la base de carga aislada.

La auditoria registra el instante y usuario REALES de la carga, no una fecha
historica inventada. Por eso su timestamp, usuario e identidad (y los tiempos)
pueden diferir entre ejecuciones. Las entidades y movimientos sinteticos se
reproducen con las mismas versiones, CSV y argumentos. El resto de los mecanismos
H1/H2 sigue siendo obligatorio al volver a operar sobre la base.

## Medicion comparable

--comparar usa exactamente los mismos datos ya generados para ambos metodos.
Primero carga individual, valida y hace rollback a un savepoint; despues carga
por lotes, valida y confirma. Ambos ejecutan las mismas tablas, restricciones,
procedimientos y triggers. Los tiempos incluyen SQL de carga, viajes cliente/servidor
y procesamiento; excluyen generacion Faker, controles finales, ANALYZE y COMMIT.

Es una medicion descriptiva de una pasada, individual primero y lotes despues;
la segunda puede beneficiarse de cache. No demuestra un factor universal ni reemplaza
H4. Puede ejecutarse --comparar con perfil completo en una base nueva si se requiere
comparar al volumen final; sera mas lento. Los JSON guardan motor, Python, Faker,
version de psycopg2, hashes CSV, conteos y tiempos. No contienen la clave.
No reemplazar evidencia de una ejecucion anterior: usar un nuevo nombre de reporte.

## Validaciones antes de confirmar

- Cada tabla no vacia y conteos exactos de clientes/comprobantes/renglones.
- Volumen final exigido para perfil completo.
- Cero huerfanos en todas las FK, incluidas las compuestas.
- Un solo subtipo y concordancia; composicion 100; al menos un maridaje.
- Superficies agregadas de parcelas no superan finca.
- Ingresos de la misma bodega que sus vinos; documentos procesados y no vacios.
- Inventario calculado desde movimientos igual a stock real y reservas planificadas.
- Montos cabecera iguales a detalle y calculo monetario correcto.
- Fechas de altas, ventas, movimientos y analisis en orden.
- Un evento real de auditoria para el cambio de precio.
- Restricciones diferidas evaluadas, triggers restaurados y secuencias ajustadas.

La validacion de descuento usa la tasa actual porque este dataset no cambia tasas
entre ventas. No es una consulta universal para auditar historia despues de U6.
El reporte se escribe despues de COMMIT: si el disco falla al escribirlo, los datos
pueden estar confirmados. Revisar la salida antes de intentar repetir la carga.

## Dump

Tras aprobar la carga completa:

```powershell
.\.venv\Scripts\python.exe exportar_h3.py --base bodegas_carga_h3_completa --salida dump_completo.sql.gz
```

Se usa pg_dump del contenedor PostgreSQL 16 y compresion binaria en Python para
no corromper el dump con redirecciones de Windows PowerShell. Si pg_dump falla,
se borra el archivo .partial. No subir el dump voluminoso a Git sin revisar el
limite del repositorio; estas instrucciones permiten regenerarlo.
El dump contiene esquema y datos, sin owners/GRANT. No es un respaldo global de
roles. Para restaurar con roles de la aplicacion, restaurar en una base nueva y
reaplicar 007_roles.sql como administrador (crea/configura roles y propietarios).
La comprobacion de restauracion del dump queda pendiente hasta ejecutarla en Docker.

## Evidencia disponible en esta entrega

Se verifico sintaxis Python, generacion determinista, volumen final generado y
carga pequena con las migraciones/triggers en PGlite. Se prueba tambien el recorrido
Python de comparacion/rollback a traves de un adaptador de consultas para ese motor.
Esto NO equivale a ejecutar psycopg2 contra PostgreSQL 16 en Windows ni a cargar
500.000 renglones en PostgreSQL real. Esos pasos se confirman con los JSON del usuario.
Mantener .venv/, __pycache__/ y *.pyc fuera de Git.
