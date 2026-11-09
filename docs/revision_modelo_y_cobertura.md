# Revision de modelo, diccionario y cobertura H1/H2

Fecha: 2026-11-09. Rama: renata/cierre-h2. Referencia: d4847bddac88f1b8f957c0b1ca38b271401e0b93.

## Resultado y alcance

Se revisaron el DDL 001, las restricciones 002, las rutinas, triggers y roles, los archivos de pruebas y el diccionario PDF. Se extrajeron los atributos del DER PDF y se contrastaron con el esquema; esta revision no certifica la legibilidad grafica ni todas las lineas/cardinalidades del PDF. El inventario de FK en modelo_relacional_vigente.md se obtiene de la implementacion.

Las migraciones 001-008 se instalaron en una instancia aislada de PGlite para consultar el catalogo y ejecutar la nueva prueba. Las nueve pruebas anteriores fueron ejecutadas por Renata en PostgreSQL 16; la decima prueba paso individualmente en PostgreSQL 16.15 el 2026-11-09. Falta ejecutar conjuntamente la suite ampliada y guardar su salida.. No se ha modificado la base del usuario ni se ha realizado un push.

## Diferencias confirmadas de documentacion

| Documento | Diferencia | Correccion entregada |
|---|---|---|
| Diccionario PDF | Solo describe 5 tablas de las 29 existentes | Diccionario completo de las 29 tablas |
| cliente | Omite descuento NUMERIC(4,2) NOT NULL, CHECK 0..1 | Incluido junto con tasas base y U6 |
| localidad | encargado_regional VARCHAR(100) nullable | VARCHAR(150) NOT NULL |
| renglon_comprobante | id_renglon/id_comprobante/id_producto y cantidad decimal | PK (numero_comprobante,cod_vino), cantidad INTEGER, precio historico y montos |
| stock_deposito | id_deposito/id_producto/cantidad_disponible/ubicacion_estanteria | cod_vino PK y cantidad INTEGER |
| stock_sala | id_sala_venta/id_producto/stock_exhibicion/punto_reposicion | PK (id_sala,cod_vino) y cantidad INTEGER |
| Funcion de descuento | Tasas antiguas 5/10; no exportador | Base 10/20/30, excepcion U6 35, resultado neto |
| DER PDF | Lista cliente sin descuento incorporado en 002 | Atributo incluido en modelo vigente/diccionario; falta actualizar el dibujo editable |
| normalizacion_3fn.md | Considera pendientes 002, triggers de ventas y asignacion de tasas | Actualizado para reflejar lo integrado |
| Rutas PDF | DER_Bodegas_del_Atuel.pdf e Informe_Etapa1.pdf son directorios | No se renombraron; el nuevo Markdown es la referencia vigente |

## Trazabilidad RN-01 a RN-15

Convenciones: EXISTENTE = caso en la suite que Renata reporto exitosa; NUEVO = caso agregado, validado en PGlite y, tras ajustar los SQLSTATE admitidos para RN-14, en PostgreSQL 16.15. Tener un caso por regla no significa probar todas sus combinaciones.

| Regla | Implementacion | Prueba y alcance |
|---|---|---|
| RN-01 precio unico y positivo | precio central en vino; chk_vino_precio_positivo | NUEVO reglas_basicas: cero/negativo rechazados. El precio historico del renglon es una instantanea, no un precio por sala |
| RN-02 localidad y encargado | FK NOT NULL sala_venta.codigo_postal; encargado unico atributo NOT NULL de localidad | NUEVO: localidad inexistente/nula y encargado nulo |
| RN-03 empleado en una sala | empleado.id_sala FK NOT NULL | NUEVO: sala inexistente y nula |
| RN-04 parcela/cepa y cosecha unica | FK NOT NULL id_cepa; UNIQUE(id_finca,nro_parcela,campana) | NUEVO: cepa inexistente/nula; segunda cosecha misma campana |
| RN-05 composicion 100 | triggers diferidos sobre composicion y alta de vino | EXISTENTE composicion_vino: 100,90,sin componentes,cascada. Concurrencia documentada solo mismo componente READ COMMITTED |
| RN-06 descuentos | cliente.descuento + CHECK; trigger base; fn_descuento_cliente | EXISTENTE descuento_base_cliente, santiago_tests, ventas_historial; U6 y recalc en descuentos.mjs |
| RN-07 permisos y fechas | FK cliente_exportador y CHECK vencimiento > emision | NUEVO: dos permisos validos; vencimiento igual/anterior rechazado |
| RN-08 importes calculados | triggers INSERT ventas, helpers y privilegios por columna | EXISTENTE ventas_operador/ventas_historial: bruto, descuento, neto e historia. Alcance de edicion administrativa descrito abajo |
| RN-09 stock | bloqueo y descuento atomico, CHECK stock >=0 | EXISTENTE ventas_operador y concurrencia_ventas; NUEVO CHECK negativo de ambos stocks |
| RN-10 ingresos | ENUM, trigger estados, terminar/procesar | EXISTENTE santiago_tests, operador_ingresos_transferencias, proteccion_cabeceras, transiciones.mjs: estados, repeticion, vacio, bodega, stock/rollback |
| RN-11 transferencias | estados/procedimientos y fecha actual inmutable | EXISTENTE movimientos/stock insuficiente/rollback; NUEVO fecha inicial forzada y cambio rechazado |
| RN-12 renglones cerrados | triggers detalle, bloqueo y verificacion de ambos padres | EXISTENTE proteccion_renglones_transferencia, depuracion_ingresos; D5 es excepcion administrativa documentada |
| RN-13 auditoria | AFTER UPDATE precio, compara OLD/NEW | NUEVO: precio anterior/nuevo, fecha, usuario y ausencia de duplicado al repetir precio |
| RN-14 borrados protegidos | FK ON DELETE RESTRICT | NUEVO: transportista, bodega y vino referenciados; SQLSTATE 23503 observado en PostgreSQL 16.15; la prueba admite 23001 o 23503 solo para RN-14 |
| RN-15 positivos y graduacion | CHECK 002 y validacion de cantidades | NUEVO: superficies, kilos, cantidades ingreso/transferencia, volumen, precio, graduacion fuera de rango y limites 5/20 |

## Decisiones y pendientes que no deben ocultarse

1. **Jerarquia de clientes:** las PK/FK de subtipos permiten a lo sumo una fila por subtipo, pero no obligan a que cada cliente tenga exactamente el subtipo declarado. No garantizan exclusividad ni concordancia con tipo_cliente. Decidir e implementar esa integridad antes de dar por cerrado el modelo; hay que contemplar altas y cambios de tipo dentro de una transaccion y adaptar sus fixtures.
2. **RN-08 y privilegios:** el operador no puede insertar montos ni editar/eliminar ventas. Los triggers de ventas actuan solo en INSERT; un administrador puede editar montos o detalles y debe mantener los totales mediante operaciones explicitas. U1 recalcula y revierte. No afirmar mantenimiento automatico general para UPDATE/DELETE.
3. **Estados iniciales:** el rol operador no puede proporcionar estado al insertar; el trigger de transiciones cubre UPDATE. Un administrador puede insertar directamente un estado cerrado. Documentar el alcance o endurecerlo si se exige garantia para todas las escrituras administrativas.
4. **RN-05 concurrencia:** evidencia disponible para dos sesiones sobre el mismo componente en READ COMMITTED. No certifica otros niveles ni todos los patrones de escritura.
5. **Historial de precios:** ON DELETE CASCADE elimina auditoria al borrar un vino sin referencias que impidan su borrado. Explicitar politica de retencion; no cambiarla incidentalmente.
6. **Modelo geografico y documentos:** cliente.localidad es texto sin FK; nro_doc UNIQUE es mas restrictivo que el par tipo_doc/nro_doc; CP como PK supone una localidad por codigo. Son decisiones que deben quedar justificadas, no fallos nuevos de las pruebas.
7. **Validacion pendiente:** ejecutar la suite ampliada en PostgreSQL 16, actualizar el DER grafico, verificar instalacion limpia final y autenticar con un usuario LOGIN de permisos minimos. SET ROLE no comprueba contrasena/autenticacion.

## Criterio para cerrar este bloque

- Diccionario y relaciones vigentes incorporados al repositorio.
- DER grafico actualizado y jerarquia decidida/validada.
- Suite ampliada ejecutada en PostgreSQL 16 con salida guardada.
- Alcances de administracion, historial y concurrencia documentados sin afirmar garantias no probadas.
- Este paquete aporta documentacion y cobertura adicional. No declara H1/H2 al 100 %.
