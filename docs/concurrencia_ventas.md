# Concurrencia: venta de la última botella

## Entorno

- PostgreSQL 16.15 en Docker.
- Dos sesiones independientes de psql.
- Nivel de aislamiento: READ COMMITTED.
- Prueba del sistema ejecutada con rol_operador_ventas.

## Caso 1: sistema con bloqueo

Preparación: una botella del vino -970 en la sala -970 y dos
comprobantes de prueba, -970 y -971.

1. A inicia una transacción e inserta un renglón de una botella
   en el comprobante -970, sin confirmar.
2. B inicia otra transacción e intenta insertar una botella
   en el comprobante -971.
3. B queda esperando el bloqueo de la fila de stock.
4. A ejecuta COMMIT.
5. B recibe:
   "Stock insuficiente del vino -970: disponible 0, solicitado 1".
6. B ejecuta ROLLBACK.

Resultado observado:
- Stock final: 0.
- Un único renglón registrado: comprobante -970, cantidad 1.
- La segunda venta no se registra.

El trigger BEFORE INSERT bloquea el stock mediante SELECT FOR UPDATE.
El trigger AFTER INSERT descuenta mediante una actualización condicionada
a que la cantidad disponible sea suficiente. Ambos operan dentro de
la transacción de la venta.

## Caso 2: demostración sin bloqueo previo

Se utilizaron tablas separadas en el esquema demo_concurrencia.
No se desactivaron los triggers del sistema.

1. El stock inicial es 1.
2. A y B inician transacciones READ COMMITTED.
3. Ambas consultan el stock sin FOR UPDATE y guardan el valor 1
   en una variable de psql.
4. A registra una venta, escribe cantidad = valor_leido - 1 y confirma.
5. B registra otra venta, escribe cantidad = valor_leido - 1 y confirma.

Resultado observado:
- Stock final: 0.
- Ventas registradas: 2.
- Botellas vendidas: 2, aunque había una sola.

Se produjo una actualización perdida: ambas sesiones escribieron 0
usando una lectura anterior. El CHECK de stock no negativo no detecta
este problema porque ningún valor almacenado fue negativo.

## Interpretación y límites

READ COMMITTED no reserva una fila por hacer un SELECT común.
SELECT FOR UPDATE mantiene el bloqueo hasta terminar la transacción;
en el caso probado, B espera y luego valida la cantidad actualizada.

La demostración no implica que toda operación sin FOR UPDATE sea
incorrecta: una actualización atómica condicionada también puede
proteger las existencias.

Se verificó la disputa por la última botella. Esto no certifica todos
los escenarios concurrentes, como ventas con varios vinos, cambios
de documentos o interacciones con transferencias.

## Limpieza

Se eliminaron las tablas del esquema demo_concurrencia y los datos
auxiliares de esta demostración. Se conservaron los triggers del sistema.