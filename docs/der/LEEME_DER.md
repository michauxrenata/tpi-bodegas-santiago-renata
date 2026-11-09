# DER actualizado - Bodegas del Atuel

Fuente: commit 2c8a252 de renata/cierre-h2, migraciones 001/002 y validaciones de 005.

## Lectura

El PDF y el editable contienen una vista general y seis areas. [ref.] indica una tabla repetida como referencia; no otra entidad. Todas las columnas son NOT NULL en esta version. ID significa GENERATED ALWAYS AS IDENTITY. PK/FK identifican claves; una PK compuesta comprende todas sus columnas marcadas PK. Los tipos ENUM, DEFAULT, CHECK y UNIQUE completos se documentan en diccionario_datos.md.

Las flechas van del padre al dependiente. `1 : 0..N` indica que cada hijo referencia un padre y el padre puede tener cero o muchos hijos. `1 : 0..1` indica una FK que es unica en el hijo. Se muestra la cardinalidad por FK; las restricciones adicionales se describen abajo.

## Reglas que complementan las cardinalidades

- Cliente: especializacion TOTAL y DISJUNTA. Cada cliente tiene exactamente uno entre socio, distribuidor y exportador, coincidente con tipo_cliente. Cada relacion individual es 1 : 0..1. Los cuatro triggers diferidos permiten estados intermedios dentro de la transaccion.
- Composicion: cada vino existente debe tener componentes cuya suma sea 100 al validar la transaccion. RN-05 impone participacion obligatoria adicional a la FK; se admite borrar vino y composicion juntos.
- Parcela: clave (id_finca,nro_parcela); UNIQUE de lote_uva(id_finca,nro_parcela,campana) limita a una cosecha por campana.
- Descuento: cliente.descuento NUMERIC(4,2) es tasa vigente; bases 10/20/30 y excepcion U6 35. Los descuentos de comprobantes y renglones son importes monetarios.
- No se agregan FK inexistentes: cliente.localidad es texto; los departamentos/provincias de finca tambien.
- RN-12 y D5 condicionan borrados por cascada de ingresos. Una FK CASCADE no implica que todos los borrados esten permitidos por los triggers.

## Relaciones exactas

| ID | Padre | Hijo / columnas FK | Borrado |
|---|---|---|---|
| F01 | lote_uva (nro_lote) | analisis_calidad (nro_lote) | CASCADE |
| F02 | vino (cod_vino) | auditoria_precio (cod_vino) | CASCADE |
| F03 | cliente (id_cliente) | cliente_distribuidor (id_cliente) | CASCADE |
| F04 | cliente (id_cliente) | cliente_exportador (id_cliente) | CASCADE |
| F05 | cliente (id_cliente) | cliente_socio (id_cliente) | CASCADE |
| F06 | vino (cod_vino) | composicion_vino (cod_vino) | CASCADE |
| F07 | cepa (id_cepa) | composicion_vino (id_cepa) | RESTRICT |
| F08 | cliente (id_cliente) | comprobante (id_cliente) | RESTRICT |
| F09 | sala_venta (id_sala) | comprobante (id_sala) | RESTRICT |
| F10 | sala_venta (id_sala) | empleado (id_sala) | RESTRICT |
| F11 | transportista (codigo_transportista) | ingreso (codigo_transportista) | RESTRICT |
| F12 | bodega (cuit) | ingreso (cuit_bodega) | RESTRICT |
| F13 | bodega (cuit) | lote_uva (cuit_bodega_destino) | RESTRICT |
| F14 | parcela (id_finca, nro_parcela) | lote_uva (id_finca, nro_parcela) | RESTRICT |
| F15 | cepa (id_cepa) | parcela (id_cepa) | RESTRICT |
| F16 | finca (id_finca) | parcela (id_finca) | CASCADE |
| F17 | cliente_exportador (id_cliente) | permiso_exportacion (id_cliente_exportador) | CASCADE |
| F18 | vino (cod_vino) | renglon_comprobante (cod_vino) | RESTRICT |
| F19 | comprobante (numero_comprobante) | renglon_comprobante (numero_comprobante) | CASCADE |
| F20 | vino (cod_vino) | renglon_ingreso (cod_vino) | RESTRICT |
| F21 | ingreso (codigo_ingreso) | renglon_ingreso (codigo_ingreso) | CASCADE |
| F22 | vino (cod_vino) | renglon_transferencia (cod_vino) | RESTRICT |
| F23 | transferencia (numero_solicitud) | renglon_transferencia (numero_solicitud) | CASCADE |
| F24 | localidad (codigo_postal) | sala_venta (codigo_postal) | RESTRICT |
| F25 | vino (cod_vino) | stock_deposito (cod_vino) | RESTRICT |
| F26 | vino (cod_vino) | stock_sala (cod_vino) | RESTRICT |
| F27 | sala_venta (id_sala) | stock_sala (id_sala) | RESTRICT |
| F28 | sala_venta (id_sala) | transferencia (id_sala) | RESTRICT |
| F29 | localidad (codigo_postal) | transportista_cobertura (codigo_postal) | RESTRICT |
| F30 | transportista (codigo_transportista) | transportista_cobertura (codigo_transportista) | CASCADE |
| F31 | bodega (cuit) | vino (cuit_bodega) | RESTRICT |
| F32 | vino (cod_vino) | vino_maridaje (cod_vino) | CASCADE |
| F33 | maridaje (id_maridaje) | vino_maridaje (id_maridaje) | RESTRICT |

## Archivos

Abrir DER_Bodegas_Actualizado.drawio en diagrams.net. Mantener este editable en Git junto al PDF. El PDF anterior se conserva hasta reemplazar referencias de README/informes. Este es un DER logico/fisico alineado con la implementacion; no modifica tablas ni valida por si solo todas las reglas de negocio.
