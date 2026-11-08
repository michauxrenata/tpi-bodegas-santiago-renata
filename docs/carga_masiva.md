# H3 · Orden topológico y estrategia frente a triggers

Responsable de esta estrategia: Santiago. El generador Faker, los catálogos,
los volúmenes finales y las mediciones de carga pertenecen a los otros entregables
H3. Este documento no afirma que esos datos ya existan.

## Orden por dependencias del esquema actual

Dentro de cada nivel las tablas pueden cargarse en cualquier orden; avanzar al
siguiente cuando todas sus referencias existan.

| Nivel | Tablas |
|---|---|
| 0 | localidad, bodega, cepa, finca, maridaje, cliente, transportista |
| 1 | sala_venta, parcela, vino, cliente_socio, cliente_distribuidor, cliente_exportador, transportista_cobertura, ingreso |
| 2 | empleado, lote_uva, composicion_vino, vino_maridaje, permiso_exportacion, stock_deposito, renglon_ingreso, transferencia, stock_sala, comprobante, auditoria_precio |
| 3 | analisis_calidad, renglon_transferencia, renglon_comprobante |

`cliente` está en nivel 0 porque su localidad es texto; si se reemplaza por FK,
pasa al nivel 1. La dependencia débil parcela → finca exige ambos campos al
cargar lote. Las identity se capturan con RETURNING o con un mapa de claves;
si se importan IDs explícitos, usar OVERRIDING SYSTEM VALUE y ajustar secuencias
al máximo al terminar (también probar que el siguiente INSERT no colisione).

## Orden operativo recomendado (triggers activos)

El orden por FK no basta para las reglas comerciales:

1. Catálogos, clientes/subtipos, bodegas, vinos con composición completa y maridajes.
   Insertar todas las cepas de cada vino en una misma transacción y forzar
   `SET CONSTRAINTS ALL IMMEDIATE` antes de confirmar para comprobar RN-05.
2. Producción: fincas, parcelas, lotes, análisis; campañas consistentes.
3. Ingresos en confección y detalles; terminar y llamar `sp_procesar_ingreso`.
4. Transferencias en confección y detalles; terminar y llamar `sp_procesar_transferencia`.
5. Comprobantes y renglones usando los triggers de venta, con stock suficiente.
   No precargar además el stock final: se contaría dos veces.
6. Validaciones y ANALYZE. El seed debe usar una fecha de referencia fija además
   de una semilla fija; CURRENT_DATE en la generación impide reproducibilidad entre días.

RN-11 fuerza fecha actual en transferencias. Por eso un historial de años requiere
una importación histórica especial; no conviene falsificar fechas después de habilitar
los triggers. Un seed con triggers activos puede usar la fecha actual para ese flujo,
pero debe declarar que no reproduce exactamente las fechas en ejecuciones futuras.

## Alternativa controlada para historia (base aislada, propietario)

Conservar FK, CHECK, UNIQUE y NOT NULL. No usar `session_replication_role=replica`
ni `DISABLE TRIGGER ALL`: se perdería la comprobación de FK. La suspensión se
limita a una lista explícita de triggers de negocio revisada con Sol, cuyo nombre
real debe tomarse de `pg_trigger` después de que se implementen.

En UNA transacción: bloquear las tablas objetivo, deshabilitar sólo los triggers
seleccionados, cargar cabeceras/detalles con fechas históricas y valores coherentes,
reconstruir stocks e importes, habilitar los mismos triggers, ejecutar validaciones
que lancen error si detectan inconsistencias y confirmar sólo si no hay errores.
Un fallo produce ROLLBACK, incluida la desactivación de triggers. No usar commits
intermedios. Registrar el estado original de cada trigger y exigir que estuviera
habilitado antes de importar. En una base compartida, usar una copia aislada.

**ENABLE TRIGGER no valida retrospectivamente filas.** RN-05, estados, stocks y
totales requieren consultas de control explícitas. Tampoco basta con ejecutar
SET CONSTRAINTS si los eventos nunca se dispararon durante la importación.
La carga no debe fabricar auditoría de cambios que nunca ocurrieron: identificar
los movimientos históricos importados y documentar su procedencia sintética.

## Controles obligatorios para Valentina/Renata

- Conteos: todas las tablas no vacías, tres con más de 10.000 y una con más de 100.000.
- FKs sin huérfanos, subtipos completos/exclusivos y coincidencia con tipo_cliente.
- Por vino, composición existente y suma exactamente 100; al menos un maridaje.
- Por parcela/campaña, a lo sumo un lote; fechas y superficies válidas.
- Depósito: ingresos procesados menos transferencias procesadas = stock actual,
  suponiendo stock inicial cero y ausencia de ajustes explícitos.
- Sala: transferencias procesadas menos ventas = stock actual; ninguna cantidad negativa.
- Por comprobante: bruto, descuento y neto iguales a la suma de renglones;
  descuentos históricos no se recalculan usando la política actual de U6.
- Fechas históricas coherentes; documentos procesados no vacíos; renglones de
  ingreso corresponden a vinos de la bodega de origen.
- No queda ningún trigger deshabilitado después del COMMIT.

Guardar resultados y tiempos reales. `database/benchmarks/fixture_sintetico.sql`
es sólo un escenario aislado para planes; NO sustituye la carga H3 ni sus controles.

## Integración de descuentos (30/10/2026)

Aplicar 001 y 002 de Valentina antes de funciones/carga: cliente.descuento ahora
es NOT NULL. Hasta integrar el trigger base de Sol, el generador debe proporcionar
0.10/0.20/0.30 según tipo; el generador de Vale revisado ya declara esas tasas.
Una vez activo el trigger, las altas normales reciben la base automáticamente.
Para generar casos U6, cargar clientes exportadores y permisos antes de ejecutar
la actualización explícita; no derivar automáticamente el 35 % de cada permiso.
Las ventas previas conservan importes. La importación histórica con tasas distintas
requiere el mecanismo controlado y validaciones descritos arriba.

No iniciar la carga operativa completa hasta resolver los bloqueos de permisos,
estados y compilación documentados en integracion_etapa2_2026-10-30.md.
