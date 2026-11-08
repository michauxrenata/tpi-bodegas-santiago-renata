# Prueba multisesión pendiente de integración

Estas instrucciones son un guion, no evidencia ejecutada. PGlite tiene una sola
conexión y no certifica concurrencia de dos clientes de PostgreSQL.

En una base local de prueba con el esquema y las rutinas instaladas, crear un vino
con **una botella en depósito**, dos salas y dos transferencias terminadas de una
botella del mismo vino. Los IDs siguientes son variables psql del fixture real:
`a` y `b` son números de solicitud diferentes. Antes de empezar, confirmar el fixture.

| Paso | Sesión A | Sesión B |
|---|---|---|
| 1 | `BEGIN ISOLATION LEVEL READ COMMITTED;` | `BEGIN ISOLATION LEVEL READ COMMITTED;` |
| 2 | `CALL sp_procesar_transferencia(:a);` | Esperar que A haya completado CALL, sin COMMIT |
| 3 | Mantener transacción abierta | `CALL sp_procesar_transferencia(:b);` queda esperando el stock |
| 4 | `COMMIT;` | Se desbloquea y falla con SQLSTATE 23514 por stock insuficiente |
| 5 | Consultar stocks y estados | `ROLLBACK;` |

Verificar: depósito cero, sala A uno, sala B cero/ausente, A procesada y B terminada.
La misma prueba llamando al MISMO documento desde B debe fallar por estado, sin
sumar dos veces. Guardar salida de ambas sesiones y `SELECT version()`.

Agregar una variante donde A ejecuta ROLLBACK: B debe continuar y procesar su
transferencia, quedando solamente el movimiento de B. Probar también un INSERT
de renglón concurrente: actualmente espera el SHARE de tabla; con RN-12 final debe
rechazarse después de revalidar el estado de la cabecera bloqueada.

La demostración de **venta de la última botella en sala** corresponde al trabajo
conjunto de Renata y Sol: requiere el trigger RN-09 que aún no está implementado.
No confundir esta transferencia de depósito con una prueba de venta.
