# Contratos de integración de los SQL de Santiago

Actualizado el 30/10/2026. Decisiones A (descuento vigente persistido) y 2
(procedimientos SECURITY DEFINER) aceptadas por Santiago. La implementación de
triggers corresponde a Sol y la de esquema/permisos a Valentina.

## Descuento vigente y U6

`public.cliente.descuento` es la única fuente de la tasa vigente. Valentina agregó
NUMERIC(4,2), NOT NULL y CHECK entre 0 y 1 en su 002_constraints.sql.
`fn_descuento_cliente(id)` devuelve esa columna, incluido 0.35; no infiere la tasa
por tipo ni por cantidad de permisos. Un cliente inexistente produce P0002.

Contrato para el trigger de clientes que debe implementar Sol:

- BEFORE INSERT: asignar siempre la tasa base del tipo (socio 0.10, distribuidor
  0.20, exportador 0.30), incluso si el INSERT envía otra tasa. Una importación
  histórica excepcional necesita el procedimiento controlado de carga.
- BEFORE UPDATE: si cambia realmente tipo_cliente, reiniciar la tasa al valor
  base del nuevo tipo. Si el tipo no cambia, conservar el descuento de NEW:
  esto permite la actualización explícita U6.
- Agregar o quitar permisos no altera automáticamente el descuento. U6 establece
  0.35 cuando el exportador tiene más de tres permisos, incluyendo vencidos:
  la consigna no exige vigencia. No reduce una tasa ya establecida al bajar a tres.
- U6 es una operación administrativa explícita, no un permiso general de edición
  de descuentos para el operador de la API. Su ejercicio termina con ROLLBACK.

El trigger de asignación base todavía no está integrado ni probado. Los fixtures
incluyen la tasa explícitamente; eso no demuestra la asignación automática.

## Funciones e importes: contrato definitivo del aporte

| Elemento | Significado |
|---|---|
| fn_descuento_cliente(id) | Tasa decimal vigente almacenada |
| fn_calcular_descuento_cliente(id, monto) | Importe NETO; conserva la firma histórica, NO devuelve el descuento monetario |
| fn_stock_sala(sala, vino) | Botellas; cero si no existe fila |
| fn_total_comprobante(numero) | Suma de subtotales NETOS almacenados |
| fn_antiguedad_anios(fecha [, referencia]) | Años completos; referencia por defecto hoy |
| renglon_comprobante.precio_unitario | Precio vigente del vino al registrar el renglón, conservado como dato histórico |
| renglon_comprobante.descuento | Importe monetario descontado, NO porcentaje |
| renglon_comprobante.subtotal | Neto después del descuento |
| comprobante.subtotal | Suma de importes brutos de los renglones |
| comprobante.descuento | Suma de descuentos monetarios de los renglones |
| comprobante.total | Suma de subtotales netos de los renglones |

Por renglón: bruto = ROUND(cantidad × precio_unitario, 2);
descuento = ROUND(bruto × tasa, 2); subtotal = bruto − descuento.
Redondear por renglón antes de sumar. Ejemplo: tres botellas de $100 al 35 %:
bruto $300, descuento $105, neto $195. Sin renglones, las sumas son cero.

Cambiar el precio del vino, el tipo/descuento del cliente o sus permisos NO
reescribe ventas anteriores. Leer una venta o actualizar su cabecera agregada
 tampoco debe recalcular sus renglones. U1 es la excepción explícita de ejercicio:
recalcula con la tasa vigente, conserva precio_unitario histórico y usa ROLLBACK.
El trigger no debe sustituir ese precio por el precio actual durante U1.

Antes de habilitar edición de ventas en la API, Sol y Valentina deben acordar
qué modificaciones de cliente, sala, vino o cantidad se permiten y cómo se
compensa el stock. Este contrato no autoriza por sí solo esas modificaciones.
La venta nueva sí debe calcular precio e importes en la BD y descontar stock
atómicamente, sin confiar en importes enviados por el cliente HTTP.

## Procesamiento y concurrencia

Los procedimientos 004 de Santiago son SECURITY DEFINER, con search_path
restringido y referencias calificadas. Bloquean cabecera FOR UPDATE, exigen
`terminado`, verifican detalles y procesan vinos en orden ascendente. Ingresos
suman por UPSERT; transferencias bloquean stock de depósito, comprueban cantidad,
descuentan y suman a sala. El estado cambia al final. No hay COMMIT interno;
un error revierte el CALL y una segunda llamada no duplica movimientos.

Regla adicional de diseño: los vinos de un ingreso deben pertenecer a su bodega
de origen. Las pruebas cubren tanto coincidencia como rechazo de otra bodega.

Se conserva temporalmente LOCK TABLE de renglones IN SHARE MODE: el RN-12
revisado todavía no bloquea cabeceras. Para quitarlo, RN-12 debe bloquear y validar
las cabeceras OLD y NEW en cambios de documento, y superar pruebas concurrentes.
El bloqueo global limita concurrencia, requiere privilegio UPDATE sobre la tabla
y no impide ediciones posteriores al COMMIT; RN-12 sigue siendo necesario.
Evitar transacciones largas que mezclen escritura de detalles y CALL. La API
requiere reintento acotado de transacción completa ante 40P01/40001.

## Permisos y responsabilidades

Valentina asigna en 007 la propiedad de los procedimientos al rol técnico
NOLOGIN. Ese rol no debe ser superusuario ni concederse como membresía al operador.
Necesita SELECT de los datos consultados, UPDATE(estado) de cabeceras,
SELECT/INSERT/UPDATE de stocks y UPDATE de tablas de renglones para el SHARE LOCK.
El operador sólo recibe EXECUTE de las rutinas permitidas y los permisos de
captura necesarios, sin UPDATE directo de stock ni de estados protegidos.

Para ventas, Sol implementa una función trigger SECURITY DEFINER con propietario
controlado por 007, search_path seguro y referencias calificadas a tablas/tipos.
El propietario debe tener sólo los privilegios requeridos por el cuerpo real:
lectura de cliente/vino/cabecera/stock, cambios de stock_sala y totales de cabecera,
y EXECUTE de auxiliares usados tras revocar PUBLIC. Valentina debe revisar esas
sentencias contra la función terminada. No basta con asegurar los procedimientos:
las funciones trigger tienen su propio contexto de permisos.

Los triggers de estados no deben volver a mover stock al ver `procesado`.
Debe existir una transición controlada a `terminado`; permitir el INSERT de un
estado protegido tampoco debe eludir el flujo. El detalle del bloqueo y los
pendientes reproducidos están en integracion_etapa2_2026-10-30.md.

## Pruebas

El runner comprueba funciones/procedimientos, S9–S12, U1–U6 y rollback; para U6
incluye 0/3/4 permisos, tasa base y 35 %, idempotencia, persistencia al eliminar
un permiso y conservación de importes históricos. También verifica que U1 usa
precio histórico aunque cambie el precio del vino. No certifica los triggers de
venta todavía pendientes ni reemplaza las pruebas globales de Renata/Sol.


## Ampliación del 06/11/2026: cierre controlado de documentos

Se incorporan sp_terminar_ingreso(INTEGER) y sp_terminar_transferencia(INTEGER).
Exigen en_confeccion, documento existente y al menos un renglón con cantidad
positiva. El ingreso también comprueba la bodega elaboradora de sus vinos.
Cambian sólo estado a terminado: no modifican stocks ni reservan existencias.
sp_procesar_* vuelve a validar el documento y, en transferencias, la disponibilidad
real al procesar. Repetir cualquiera de los cierres produce 23514; ID ausente o
NULL produce P0002. No hay COMMIT interno y el llamador puede hacer ROLLBACK.

Conservan SECURITY DEFINER, search_path restringido y el mismo orden de bloqueo
que sp_procesar_* (SHARE de detalles antes del FOR UPDATE de cabecera). El bloqueo
global sigue siendo temporal; no se declara resuelta la concurrencia de RN-12.

Vale ya publicó el permiso UPDATE requerido para el SHARE LOCK. Las dos rutinas
nuevas requieren asignación de propietario y EXECUTE en 007; el detalle exacto
está en transiciones_terminado.md. Hasta integrar esas sentencias, el operador no
puede llamarlas. No se modificó 007 ni se concedió UPDATE(estado) al operador.

El flujo completo aún depende de que Sol proteja los detalles después del cierre,
las cabeceras relevantes y los INSERT con estado explícito. La nueva operación
proporciona una vía autorizada, pero no elimina por sí sola esas otras vías.
