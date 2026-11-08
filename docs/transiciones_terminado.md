# Santiago — cierre controlado de ingresos y transferencias

Entrega del 06/11/2026, basada en feda15e de santiago/datos-h1-h5.

## Problema y comportamiento

La API puede capturar documentos y llamar a sp_procesar_*, pero no tiene UPDATE
sobre estado. Los procedimientos existentes exigen que el documento ya esté
terminado. Se agregan dos operaciones acotadas en 004_procedimientos.sql:

```sql
CALL public.sp_terminar_ingreso(123);
CALL public.sp_terminar_transferencia(456);
```

Aceptan sólo documentos en confección, con detalles válidos. El ingreso exige
vinos de su bodega de origen, como ya exige su procesamiento. La transferencia
puede terminarse aunque todavía falte stock: terminar no reserva ni mueve
existencias. La validación definitiva del stock sigue en sp_procesar_transferencia.
La sala, transportista y bodega deben existir por las FK del esquema.

Después del cierre se llama a sp_procesar_* como antes. Se pueden hacer ambos
CALL en una misma transacción cuando se desea confirmar todo o revertir todo.
Un error de procesamiento revierte ese CALL; si el cierre se confirmó antes en
otra transacción, el documento permanece terminado. Ningún procedimiento hace COMMIT.

## Integración para Valentina (no aplicada a su archivo)

Después de crear las cuatro rutinas con 004 y antes de usar la API, incorporar
en 007, ejecutando como administrador de migraciones:

```sql
ALTER PROCEDURE public.sp_terminar_ingreso(INTEGER)
OWNER TO rol_propietario_procedimientos;
ALTER PROCEDURE public.sp_terminar_transferencia(INTEGER)
OWNER TO rol_propietario_procedimientos;
GRANT EXECUTE ON PROCEDURE public.sp_terminar_ingreso(INTEGER),
    public.sp_terminar_transferencia(INTEGER)
TO rol_operador_ventas;
```

Los privilegios de tablas del rol técnico publicados en 657ec99 ya alcanzan.
No dar al operador UPDATE(estado), UPDATE de stock ni membresía del rol técnico.
Las rutinas nuevas revocan PUBLIC al crearse. No se modificó 007 de Valentina.
En una BD existente no ejecutar el instalador completo: el administrador aplica
004 actualizado y las asignaciones anteriores dentro de una transacción revisada.

## Validación reproducible y límites

Desde la raíz:

```powershell
git fetch origin
cd tools/validacion_sql
npm.cmd ci
npm.cmd test
npm.cmd run test:transiciones
```

La prueba nueva usa PGlite en memoria, rutinas locales y 002/006/007 de Vale
fijados al commit 657ec99c3b38b58d98865e514716850059a5aca5. git fetch debe haber
traído ese commit. Aplica las cuatro sentencias propuestas sólo en la base de
prueba; no copia ni edita archivos de otras integrantes.

Comprueba privilegios antes de integrar, rechazo de UPDATE directo de estado y
stock, flujo válido con rol de operador, ausencia de movimientos al terminar,
IDs ausentes/nulos, vacíos, bodega incompatible, cierre repetido, reprocesamiento,
stock insuficiente y rollback de los cambios de prueba.

Usa el 005 básico de la rama de Santiago. NO es validación del 005 completo de
Sol, que en la versión revisada todavía tiene un error de compilación. Tampoco
simula dos conexiones ni certifica instalación en Docker. La regresión antigua
conserva casos que fuerzan estados como administrador para probar el procesador;
la prueba nueva sí recorre el flujo normal bajo permisos restringidos.

## Pendientes del equipo

- Sol: terminar triggers, corregir RAISE, proteger detalles y cabeceras según
  estado y bloquear el INSERT con estado protegido. El operador aún tiene
  INSERT general de documentos en el 007 revisado; no considerar cerrado ese hueco.
- Vale: incorporar propiedad y EXECUTE de estas dos rutinas en 007.
- Renata/Sol: validar concurrencia real con edición de detalles y cierre, evitando
  afirmar que el bloqueo global transitorio equivale al control RN-12 definitivo.
- El diagnóstico revisar_integracion.mjs anterior fija versiones del 30/10:
  es evidencia histórica, no el estado de los permisos nuevos de Vale. La prueba
  test:transiciones verifica la versión nueva y confirma que el SHARE LOCK funciona.

No se fusionaron ramas ni se modificaron main, 002, 005, 006 o 007. El siguiente
paso del equipo es integrar y probar estas dependencias en una base descartable.
