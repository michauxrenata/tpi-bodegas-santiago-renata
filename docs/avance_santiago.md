# Avance de Santiago al 30/10/2026

Este aporte parte de 87b2469 en santiago/datos-h1-h5. No reemplaza archivos de
constraints, triggers, roles ni vistas de otras integrantes.

| Tarea | Entrega | Dependencia pendiente |
|---|---|---|
| H1 | Justificación actualizada del descuento persistido | Revisión conjunta del modelo |
| H2 | fn_descuento_cliente lee cliente.descuento; contrato monetario documentado | Integrar 002 de Vale y triggers/permisos |
| H2 procedimientos | Se conserva 004 SECURITY DEFINER ya publicado | Permisos del lock, transición controlada y concurrencia |
| H3 | Orden topológico y estrategia de carga actualizados | Completar generador y triggers |
| H4 | Cinco índices candidatos y scripts ya entregados | Dataset representativo y mediciones finales |
| H5 | S9–S12 y U1–U6, con pruebas de resultados | Vista S9 y regresión con todos los triggers |
| H6–H9 | Contratos para integración | Base API/front, nube e instalación integrada |

U6 está implementada: exportadores con más de tres permisos pasan a 0.35.
No modifica ventas anteriores, no cuenta sólo permisos vigentes y no revierte la
tasa cuando luego se elimina un permiso. La función retorna el descuento vigente.
El trigger de asignación base queda a cargo de Sol según contratos_datos.md.

## Pruebas aisladas

Desde la raíz, con Node/npm instalados:

```powershell
git fetch origin
cd tools/validacion_sql
npm.cmd ci
npm.cmd test
```

El runner crea y descarta PostgreSQL embebido PGlite. Usa 002 local si está
integrado; en caso contrario lee el commit de Vale 5cf3e0b mediante git show,
únicamente en memoria. Por eso se requiere git fetch. No escribe su migración ni
se conecta a Docker/nube. Aplica el 005 local: no debe confundirse con la versión
más reciente de Sol, que se diagnostica por separado.

Pasaron funciones, procedimientos, S9–S12, U1–U6 y rollback. Las regresiones de
U6 incluyen 0/3/4 permisos, 35 %, repetición sin cambios, historial intacto y U1
usando precio histórico. Evidencia: evidencias/descuentos_2026-10-30.txt.
La asignación automática de la tasa base no se afirma probada: falta su trigger.

Para el diagnóstico de las ramas revisadas, desde la raíz:

```powershell
node tools/validacion_sql/revisar_integracion.mjs
```

Actualmente devuelve código 1 por tres bloqueos descritos en
integracion_etapa2_2026-10-30.md. No certificamos H2 completo.

La alternativa psql usa database/instalar_santiago.sql sólo en una base VACÍA
y descartable, después de integrar físicamente 002 de Valentina; luego ejecuta
database/tests/santiago_tests.sql. El runner añade las regresiones de consultas
que no están en ese archivo. Los ejercicios de update.sql usan BEGIN/ROLLBACK:
no quitar ROLLBACK para aplicarlos a datos reales sin revisar el alcance.

Los planes previos de docs/evidencias/planes_embebido.json siguen siendo evidencia
preliminar del 21/10, no mediciones nuevas ni resultados de Docker. H4 permanece
abierto hasta disponer de la carga representativa.

## Continuación del 06/11/2026

Se agregan sp_terminar_ingreso y sp_terminar_transferencia a 004, con la vía
controlada en_confeccion → terminado, sin movimientos de stock. El flujo se probó
con los roles nuevos de Vale y las asignaciones propuestas para estas rutinas.
Detalles, instrucciones y límites: transiciones_terminado.md. Prueba adicional:
`npm.cmd run test:transiciones` desde tools/validacion_sql.

El permiso del SHARE LOCK ya está resuelto en la rama de Vale (657ec99). Los
bloqueos documentados al 30/10 son históricos; no todos siguen vigentes. El cierre
está implementado en este aporte, pero requiere que Vale incorpore los nuevos
ALTER PROCEDURE/GRANT y Sol complete los controles de estado/renglones.
