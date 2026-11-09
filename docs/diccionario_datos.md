# Diccionario de datos vigente

Fuente: migraciones 001–008 de `renata/cierre-h2`, commit `d4847bddac88f1b8f957c0b1ca38b271401e0b93`.

Generado a partir del catalogo de una instalacion aislada. Describe la implementacion, no requisitos pendientes. Las restricciones se listan por tabla. Validacion local: PGlite; la prueba reglas_basicas.sql tambien paso en PostgreSQL 16.15 el 2026-11-09, con validacion diferida y ROLLBACK.
## Convenciones

- Las identidades son GENERATED ALWAYS; los IDs negativos se reservan para pruebas.
- Cantidades de botellas: enteros. Dinero: NUMERIC. Stock cero es valido.
- `cliente.descuento` es una tasa: 0.10, 0.20, 0.30; U6 permite 0.35.
- `renglon_comprobante.precio_unitario` conserva el precio historico. `descuento` es importe monetario; `subtotal` es neto.
- En `comprobante`, `subtotal` es bruto, `descuento` es bonificacion monetaria y `total` es neto.
- `fn_calcular_descuento_cliente` devuelve el monto neto, no la bonificacion.
- `cuit_dom` comprueba once digitos, no el digito verificador.
- TIMESTAMP sin zona requiere una politica horaria documentada al desplegar.

## analisis_calidad

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_analisis | integer | No | GENERATED ALWAYS AS IDENTITY |
| nro_lote | integer | No | — |
| fecha | date | No | — |
| grado_brix | numeric(4,2) | No | — |
| ph | numeric(3,2) | No | — |
| acidez_total | numeric(5,2) | No | — |

Restricciones:

- `analisis_calidad_nro_lote_fkey`: `FOREIGN KEY (nro_lote) REFERENCES lote_uva(nro_lote) ON DELETE CASCADE`.
- `analisis_calidad_acidez_total_not_null`: `NOT NULL acidez_total`.
- `analisis_calidad_fecha_not_null`: `NOT NULL fecha`.
- `analisis_calidad_grado_brix_not_null`: `NOT NULL grado_brix`.
- `analisis_calidad_id_analisis_not_null`: `NOT NULL id_analisis`.
- `analisis_calidad_nro_lote_not_null`: `NOT NULL nro_lote`.
- `analisis_calidad_ph_not_null`: `NOT NULL ph`.
- `analisis_calidad_pkey`: `PRIMARY KEY (id_analisis)`.

## auditoria_precio

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_auditoria | integer | No | GENERATED ALWAYS AS IDENTITY |
| cod_vino | integer | No | — |
| precio_anterior | numeric(10,2) | No | — |
| precio_nuevo | numeric(10,2) | No | — |
| fecha_hora | timestamp without time zone | No | CURRENT_TIMESTAMP |
| usuario | character varying(100) | No | CURRENT_USER |

Restricciones:

- `auditoria_precio_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE CASCADE`.
- `auditoria_precio_cod_vino_not_null`: `NOT NULL cod_vino`.
- `auditoria_precio_fecha_hora_not_null`: `NOT NULL fecha_hora`.
- `auditoria_precio_id_auditoria_not_null`: `NOT NULL id_auditoria`.
- `auditoria_precio_precio_anterior_not_null`: `NOT NULL precio_anterior`.
- `auditoria_precio_precio_nuevo_not_null`: `NOT NULL precio_nuevo`.
- `auditoria_precio_usuario_not_null`: `NOT NULL usuario`.
- `auditoria_precio_pkey`: `PRIMARY KEY (id_auditoria)`.

## bodega

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cuit | cuit_dom | No | — |
| razon_social | character varying(150) | No | — |
| domicilio | character varying(200) | No | — |

Restricciones:

- `bodega_cuit_not_null`: `NOT NULL cuit`.
- `bodega_domicilio_not_null`: `NOT NULL domicilio`.
- `bodega_razon_social_not_null`: `NOT NULL razon_social`.
- `bodega_pkey`: `PRIMARY KEY (cuit)`.
- `uq_bodega_razon_social`: `UNIQUE (razon_social)`.

## cepa

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_cepa | integer | No | GENERATED ALWAYS AS IDENTITY |
| nombre | character varying(100) | No | — |
| tipo | tipo_cepa | No | — |

Restricciones:

- `cepa_id_cepa_not_null`: `NOT NULL id_cepa`.
- `cepa_nombre_not_null`: `NOT NULL nombre`.
- `cepa_tipo_not_null`: `NOT NULL tipo`.
- `cepa_pkey`: `PRIMARY KEY (id_cepa)`.
- `cepa_nombre_key`: `UNIQUE (nombre)`.

## cliente

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_cliente | integer | No | GENERATED ALWAYS AS IDENTITY |
| nombre_razon_social | character varying(150) | No | — |
| tipo_doc | character varying(20) | No | — |
| nro_doc | character varying(30) | No | — |
| direccion | character varying(200) | No | — |
| localidad | character varying(100) | No | — |
| fecha_alta | date | No | CURRENT_DATE |
| tipo_cliente | tipo_cliente_enum | No | — |
| descuento | numeric(4,2) | No | — |

Restricciones:

- `chk_cliente_descuento_rango`: `CHECK (((descuento >= (0)::numeric) AND (descuento <= (1)::numeric)))`.
- `cliente_descuento_not_null`: `NOT NULL descuento`.
- `cliente_direccion_not_null`: `NOT NULL direccion`.
- `cliente_fecha_alta_not_null`: `NOT NULL fecha_alta`.
- `cliente_id_cliente_not_null`: `NOT NULL id_cliente`.
- `cliente_localidad_not_null`: `NOT NULL localidad`.
- `cliente_nombre_razon_social_not_null`: `NOT NULL nombre_razon_social`.
- `cliente_nro_doc_not_null`: `NOT NULL nro_doc`.
- `cliente_tipo_cliente_not_null`: `NOT NULL tipo_cliente`.
- `cliente_tipo_doc_not_null`: `NOT NULL tipo_doc`.
- `cliente_pkey`: `PRIMARY KEY (id_cliente)`.
- `cliente_nro_doc_key`: `UNIQUE (nro_doc)`.

Triggers:

- `CREATE TRIGGER trg_descuento_base_cliente BEFORE INSERT OR UPDATE OF tipo_cliente ON public.cliente FOR EACH ROW EXECUTE FUNCTION fn_trg_descuento_base_cliente()`.

## cliente_distribuidor

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_cliente | integer | No | — |
| zona_cobertura | character varying(150) | No | — |
| nro_habilitacion | character varying(50) | No | — |

Restricciones:

- `cliente_distribuidor_id_cliente_fkey`: `FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE`.
- `cliente_distribuidor_id_cliente_not_null`: `NOT NULL id_cliente`.
- `cliente_distribuidor_nro_habilitacion_not_null`: `NOT NULL nro_habilitacion`.
- `cliente_distribuidor_zona_cobertura_not_null`: `NOT NULL zona_cobertura`.
- `cliente_distribuidor_pkey`: `PRIMARY KEY (id_cliente)`.
- `cliente_distribuidor_nro_habilitacion_key`: `UNIQUE (nro_habilitacion)`.

## cliente_exportador

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_cliente | integer | No | — |
| pais_destino_principal | character varying(100) | No | — |

Restricciones:

- `cliente_exportador_id_cliente_fkey`: `FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE`.
- `cliente_exportador_id_cliente_not_null`: `NOT NULL id_cliente`.
- `cliente_exportador_pais_destino_principal_not_null`: `NOT NULL pais_destino_principal`.
- `cliente_exportador_pkey`: `PRIMARY KEY (id_cliente)`.

## cliente_socio

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_cliente | integer | No | — |

Restricciones:

- `cliente_socio_id_cliente_fkey`: `FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE`.
- `cliente_socio_id_cliente_not_null`: `NOT NULL id_cliente`.
- `cliente_socio_pkey`: `PRIMARY KEY (id_cliente)`.

## composicion_vino

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cod_vino | integer | No | — |
| id_cepa | integer | No | — |
| porcentaje | numeric(5,2) | No | — |

Restricciones:

- `chk_composicion_porcentaje`: `CHECK (((porcentaje > (0)::numeric) AND (porcentaje <= (100)::numeric)))`.
- `composicion_vino_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE CASCADE`.
- `composicion_vino_id_cepa_fkey`: `FOREIGN KEY (id_cepa) REFERENCES cepa(id_cepa) ON DELETE RESTRICT`.
- `composicion_vino_cod_vino_not_null`: `NOT NULL cod_vino`.
- `composicion_vino_id_cepa_not_null`: `NOT NULL id_cepa`.
- `composicion_vino_porcentaje_not_null`: `NOT NULL porcentaje`.
- `composicion_vino_pkey`: `PRIMARY KEY (cod_vino, id_cepa)`.
- `trg_validar_composicion_vino`: `TRIGGER DEFERRABLE INITIALLY DEFERRED`.

Triggers:

- `CREATE CONSTRAINT TRIGGER trg_validar_composicion_vino AFTER INSERT OR DELETE OR UPDATE ON public.composicion_vino DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_composicion_vino()`.

## comprobante

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| numero_comprobante | integer | No | GENERATED ALWAYS AS IDENTITY |
| fecha | timestamp without time zone | No | CURRENT_TIMESTAMP |
| id_cliente | integer | No | — |
| id_sala | integer | No | — |
| subtotal | numeric(12,2) | No | 0 |
| descuento | numeric(12,2) | No | 0 |
| total | numeric(12,2) | No | 0 |

Restricciones:

- `comprobante_id_cliente_fkey`: `FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT`.
- `comprobante_id_sala_fkey`: `FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT`.
- `comprobante_descuento_not_null`: `NOT NULL descuento`.
- `comprobante_fecha_not_null`: `NOT NULL fecha`.
- `comprobante_id_cliente_not_null`: `NOT NULL id_cliente`.
- `comprobante_id_sala_not_null`: `NOT NULL id_sala`.
- `comprobante_numero_comprobante_not_null`: `NOT NULL numero_comprobante`.
- `comprobante_subtotal_not_null`: `NOT NULL subtotal`.
- `comprobante_total_not_null`: `NOT NULL total`.
- `comprobante_pkey`: `PRIMARY KEY (numero_comprobante)`.

## empleado

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cuit | cuit_dom | No | — |
| nombre | character varying(150) | No | — |
| fecha_ingreso | date | No | — |
| salario | numeric(12,2) | No | — |
| id_sala | integer | No | — |

Restricciones:

- `chk_empleado_salario_positivo`: `CHECK ((salario > (0)::numeric))`.
- `empleado_id_sala_fkey`: `FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT`.
- `empleado_cuit_not_null`: `NOT NULL cuit`.
- `empleado_fecha_ingreso_not_null`: `NOT NULL fecha_ingreso`.
- `empleado_id_sala_not_null`: `NOT NULL id_sala`.
- `empleado_nombre_not_null`: `NOT NULL nombre`.
- `empleado_salario_not_null`: `NOT NULL salario`.
- `empleado_pkey`: `PRIMARY KEY (cuit)`.

## finca

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_finca | integer | No | GENERATED ALWAYS AS IDENTITY |
| nombre | character varying(100) | No | — |
| superficie_ha | numeric(8,2) | No | — |
| departamento | character varying(100) | No | — |
| provincia | character varying(100) | No | — |

Restricciones:

- `chk_finca_superficie_positiva`: `CHECK ((superficie_ha > (0)::numeric))`.
- `finca_departamento_not_null`: `NOT NULL departamento`.
- `finca_id_finca_not_null`: `NOT NULL id_finca`.
- `finca_nombre_not_null`: `NOT NULL nombre`.
- `finca_provincia_not_null`: `NOT NULL provincia`.
- `finca_superficie_ha_not_null`: `NOT NULL superficie_ha`.
- `finca_pkey`: `PRIMARY KEY (id_finca)`.

## ingreso

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| codigo_ingreso | integer | No | GENERATED ALWAYS AS IDENTITY |
| fecha | date | No | CURRENT_DATE |
| estado | estado_documento | No | 'en_confeccion'::estado_documento |
| codigo_transportista | integer | No | — |
| cuit_bodega | cuit_dom | No | — |

Restricciones:

- `ingreso_codigo_transportista_fkey`: `FOREIGN KEY (codigo_transportista) REFERENCES transportista(codigo_transportista) ON DELETE RESTRICT`.
- `ingreso_cuit_bodega_fkey`: `FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) ON DELETE RESTRICT`.
- `ingreso_codigo_ingreso_not_null`: `NOT NULL codigo_ingreso`.
- `ingreso_codigo_transportista_not_null`: `NOT NULL codigo_transportista`.
- `ingreso_cuit_bodega_not_null`: `NOT NULL cuit_bodega`.
- `ingreso_estado_not_null`: `NOT NULL estado`.
- `ingreso_fecha_not_null`: `NOT NULL fecha`.
- `ingreso_pkey`: `PRIMARY KEY (codigo_ingreso)`.

Triggers:

- `CREATE TRIGGER trg_proteger_cabecera_ingreso BEFORE UPDATE ON public.ingreso FOR EACH ROW EXECUTE FUNCTION fn_trg_proteger_cabecera_documento()`.
- `CREATE TRIGGER trg_validar_borrado_ingreso BEFORE DELETE ON public.ingreso FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_borrado_ingreso()`.
- `CREATE TRIGGER trg_validar_estado_ingreso BEFORE UPDATE OF estado ON public.ingreso FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_transicion_estado()`.

## localidad

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| codigo_postal | character varying(10) | No | — |
| nombre | character varying(100) | No | — |
| provincia | character varying(100) | No | — |
| encargado_regional | character varying(150) | No | — |

Restricciones:

- `localidad_codigo_postal_not_null`: `NOT NULL codigo_postal`.
- `localidad_encargado_regional_not_null`: `NOT NULL encargado_regional`.
- `localidad_nombre_not_null`: `NOT NULL nombre`.
- `localidad_provincia_not_null`: `NOT NULL provincia`.
- `localidad_pkey`: `PRIMARY KEY (codigo_postal)`.

## lote_uva

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| nro_lote | integer | No | GENERATED ALWAYS AS IDENTITY |
| id_finca | integer | No | — |
| nro_parcela | integer | No | — |
| campana | smallint | No | — |
| fecha_cosecha | date | No | — |
| kg_cosechados | numeric(10,2) | No | — |
| cuit_bodega_destino | cuit_dom | No | — |

Restricciones:

- `chk_lote_kilos_positivos`: `CHECK ((kg_cosechados > (0)::numeric))`.
- `lote_uva_cuit_bodega_destino_fkey`: `FOREIGN KEY (cuit_bodega_destino) REFERENCES bodega(cuit) ON DELETE RESTRICT`.
- `lote_uva_id_finca_nro_parcela_fkey`: `FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela(id_finca, nro_parcela) ON DELETE RESTRICT`.
- `lote_uva_campana_not_null`: `NOT NULL campana`.
- `lote_uva_cuit_bodega_destino_not_null`: `NOT NULL cuit_bodega_destino`.
- `lote_uva_fecha_cosecha_not_null`: `NOT NULL fecha_cosecha`.
- `lote_uva_id_finca_not_null`: `NOT NULL id_finca`.
- `lote_uva_kg_cosechados_not_null`: `NOT NULL kg_cosechados`.
- `lote_uva_nro_lote_not_null`: `NOT NULL nro_lote`.
- `lote_uva_nro_parcela_not_null`: `NOT NULL nro_parcela`.
- `lote_uva_pkey`: `PRIMARY KEY (nro_lote)`.
- `uq_lote_parcela_campana`: `UNIQUE (id_finca, nro_parcela, campana)`.

## maridaje

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_maridaje | integer | No | GENERATED ALWAYS AS IDENTITY |
| nombre | character varying(100) | No | — |
| temp_servicio_sugerida_c | numeric(4,1) | No | — |

Restricciones:

- `maridaje_id_maridaje_not_null`: `NOT NULL id_maridaje`.
- `maridaje_nombre_not_null`: `NOT NULL nombre`.
- `maridaje_temp_servicio_sugerida_c_not_null`: `NOT NULL temp_servicio_sugerida_c`.
- `maridaje_pkey`: `PRIMARY KEY (id_maridaje)`.
- `maridaje_nombre_key`: `UNIQUE (nombre)`.

## parcela

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_finca | integer | No | — |
| nro_parcela | integer | No | — |
| superficie_ha | numeric(8,2) | No | — |
| anio_plantacion | smallint | No | — |
| id_cepa | integer | No | — |

Restricciones:

- `chk_parcela_superficie_positiva`: `CHECK ((superficie_ha > (0)::numeric))`.
- `parcela_id_cepa_fkey`: `FOREIGN KEY (id_cepa) REFERENCES cepa(id_cepa) ON DELETE RESTRICT`.
- `parcela_id_finca_fkey`: `FOREIGN KEY (id_finca) REFERENCES finca(id_finca) ON DELETE CASCADE`.
- `parcela_anio_plantacion_not_null`: `NOT NULL anio_plantacion`.
- `parcela_id_cepa_not_null`: `NOT NULL id_cepa`.
- `parcela_id_finca_not_null`: `NOT NULL id_finca`.
- `parcela_nro_parcela_not_null`: `NOT NULL nro_parcela`.
- `parcela_superficie_ha_not_null`: `NOT NULL superficie_ha`.
- `parcela_pkey`: `PRIMARY KEY (id_finca, nro_parcela)`.

## permiso_exportacion

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cod_permiso | character varying(50) | No | — |
| id_cliente_exportador | integer | No | — |
| fecha_emision | date | No | — |
| fecha_vencimiento | date | No | — |

Restricciones:

- `chk_fechas_permiso`: `CHECK ((fecha_vencimiento > fecha_emision))`.
- `permiso_exportacion_id_cliente_exportador_fkey`: `FOREIGN KEY (id_cliente_exportador) REFERENCES cliente_exportador(id_cliente) ON DELETE CASCADE`.
- `permiso_exportacion_cod_permiso_not_null`: `NOT NULL cod_permiso`.
- `permiso_exportacion_fecha_emision_not_null`: `NOT NULL fecha_emision`.
- `permiso_exportacion_fecha_vencimiento_not_null`: `NOT NULL fecha_vencimiento`.
- `permiso_exportacion_id_cliente_exportador_not_null`: `NOT NULL id_cliente_exportador`.
- `permiso_exportacion_pkey`: `PRIMARY KEY (cod_permiso)`.

## renglon_comprobante

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| numero_comprobante | integer | No | — |
| cod_vino | integer | No | — |
| cantidad | integer | No | — |
| precio_unitario | numeric(10,2) | No | — |
| descuento | numeric(10,2) | No | 0 |
| subtotal | numeric(12,2) | No | — |

Restricciones:

- `chk_cant_comprobante_positiva`: `CHECK ((cantidad > 0))`.
- `renglon_comprobante_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT`.
- `renglon_comprobante_numero_comprobante_fkey`: `FOREIGN KEY (numero_comprobante) REFERENCES comprobante(numero_comprobante) ON DELETE CASCADE`.
- `renglon_comprobante_cantidad_not_null`: `NOT NULL cantidad`.
- `renglon_comprobante_cod_vino_not_null`: `NOT NULL cod_vino`.
- `renglon_comprobante_descuento_not_null`: `NOT NULL descuento`.
- `renglon_comprobante_numero_comprobante_not_null`: `NOT NULL numero_comprobante`.
- `renglon_comprobante_precio_unitario_not_null`: `NOT NULL precio_unitario`.
- `renglon_comprobante_subtotal_not_null`: `NOT NULL subtotal`.
- `renglon_comprobante_pkey`: `PRIMARY KEY (numero_comprobante, cod_vino)`.

Triggers:

- `CREATE TRIGGER trg_aplicar_venta AFTER INSERT ON public.renglon_comprobante FOR EACH ROW EXECUTE FUNCTION fn_trg_aplicar_venta()`.
- `CREATE TRIGGER trg_calcular_renglon_venta BEFORE INSERT ON public.renglon_comprobante FOR EACH ROW EXECUTE FUNCTION fn_trg_calcular_renglon_venta()`.
- `CREATE TRIGGER trg_validar_cantidad_comprobante BEFORE INSERT OR UPDATE ON public.renglon_comprobante FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_cantidad_comprobante()`.
- `CREATE TRIGGER trg_validar_stock_venta BEFORE INSERT ON public.renglon_comprobante FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_stock_venta()`.

## renglon_ingreso

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| codigo_ingreso | integer | No | — |
| cod_vino | integer | No | — |
| cantidad | integer | No | — |

Restricciones:

- `chk_cant_ingreso_positiva`: `CHECK ((cantidad > 0))`.
- `renglon_ingreso_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT`.
- `renglon_ingreso_codigo_ingreso_fkey`: `FOREIGN KEY (codigo_ingreso) REFERENCES ingreso(codigo_ingreso) ON DELETE CASCADE`.
- `renglon_ingreso_cantidad_not_null`: `NOT NULL cantidad`.
- `renglon_ingreso_cod_vino_not_null`: `NOT NULL cod_vino`.
- `renglon_ingreso_codigo_ingreso_not_null`: `NOT NULL codigo_ingreso`.
- `renglon_ingreso_pkey`: `PRIMARY KEY (codigo_ingreso, cod_vino)`.

Triggers:

- `CREATE TRIGGER trg_bloquear_renglon_ingreso BEFORE INSERT OR DELETE OR UPDATE ON public.renglon_ingreso FOR EACH ROW EXECUTE FUNCTION fn_trg_bloquear_renglon_ingreso()`.

## renglon_transferencia

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| numero_solicitud | integer | No | — |
| cod_vino | integer | No | — |
| cantidad | integer | No | — |

Restricciones:

- `chk_cant_transferencia_positiva`: `CHECK ((cantidad > 0))`.
- `renglon_transferencia_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT`.
- `renglon_transferencia_numero_solicitud_fkey`: `FOREIGN KEY (numero_solicitud) REFERENCES transferencia(numero_solicitud) ON DELETE CASCADE`.
- `renglon_transferencia_cantidad_not_null`: `NOT NULL cantidad`.
- `renglon_transferencia_cod_vino_not_null`: `NOT NULL cod_vino`.
- `renglon_transferencia_numero_solicitud_not_null`: `NOT NULL numero_solicitud`.
- `renglon_transferencia_pkey`: `PRIMARY KEY (numero_solicitud, cod_vino)`.

Triggers:

- `CREATE TRIGGER trg_bloquear_renglon_transferencia BEFORE INSERT OR DELETE OR UPDATE ON public.renglon_transferencia FOR EACH ROW EXECUTE FUNCTION fn_trg_bloquear_renglon_transferencia()`.

## sala_venta

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_sala | integer | No | GENERATED ALWAYS AS IDENTITY |
| calle | character varying(100) | No | — |
| numero | character varying(20) | No | — |
| dia_cierre | character varying(15) | No | — |
| codigo_postal | character varying(10) | No | — |

Restricciones:

- `sala_venta_codigo_postal_fkey`: `FOREIGN KEY (codigo_postal) REFERENCES localidad(codigo_postal) ON DELETE RESTRICT`.
- `sala_venta_calle_not_null`: `NOT NULL calle`.
- `sala_venta_codigo_postal_not_null`: `NOT NULL codigo_postal`.
- `sala_venta_dia_cierre_not_null`: `NOT NULL dia_cierre`.
- `sala_venta_id_sala_not_null`: `NOT NULL id_sala`.
- `sala_venta_numero_not_null`: `NOT NULL numero`.
- `sala_venta_pkey`: `PRIMARY KEY (id_sala)`.

## stock_deposito

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cod_vino | integer | No | — |
| cantidad | integer | No | 0 |

Restricciones:

- `chk_stock_deposito_no_negativo`: `CHECK ((cantidad >= 0))`.
- `stock_deposito_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT`.
- `stock_deposito_cantidad_not_null`: `NOT NULL cantidad`.
- `stock_deposito_cod_vino_not_null`: `NOT NULL cod_vino`.
- `stock_deposito_pkey`: `PRIMARY KEY (cod_vino)`.

## stock_sala

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| id_sala | integer | No | — |
| cod_vino | integer | No | — |
| cantidad | integer | No | 0 |

Restricciones:

- `chk_stock_sala_no_negativo`: `CHECK ((cantidad >= 0))`.
- `stock_sala_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT`.
- `stock_sala_id_sala_fkey`: `FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT`.
- `stock_sala_cantidad_not_null`: `NOT NULL cantidad`.
- `stock_sala_cod_vino_not_null`: `NOT NULL cod_vino`.
- `stock_sala_id_sala_not_null`: `NOT NULL id_sala`.
- `stock_sala_pkey`: `PRIMARY KEY (id_sala, cod_vino)`.

## transferencia

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| numero_solicitud | integer | No | GENERATED ALWAYS AS IDENTITY |
| id_sala | integer | No | — |
| fecha_confeccion | date | No | CURRENT_DATE |
| estado | estado_documento | No | 'en_confeccion'::estado_documento |

Restricciones:

- `transferencia_id_sala_fkey`: `FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT`.
- `transferencia_estado_not_null`: `NOT NULL estado`.
- `transferencia_fecha_confeccion_not_null`: `NOT NULL fecha_confeccion`.
- `transferencia_id_sala_not_null`: `NOT NULL id_sala`.
- `transferencia_numero_solicitud_not_null`: `NOT NULL numero_solicitud`.
- `transferencia_pkey`: `PRIMARY KEY (numero_solicitud)`.

Triggers:

- `CREATE TRIGGER trg_proteger_cabecera_transferencia BEFORE UPDATE ON public.transferencia FOR EACH ROW EXECUTE FUNCTION fn_trg_proteger_cabecera_documento()`.
- `CREATE TRIGGER trg_proteger_fecha_transferencia BEFORE INSERT OR UPDATE OF fecha_confeccion ON public.transferencia FOR EACH ROW EXECUTE FUNCTION fn_trg_proteger_fecha_transferencia()`.
- `CREATE TRIGGER trg_validar_estado_transferencia BEFORE UPDATE OF estado ON public.transferencia FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_transicion_estado()`.

## transportista

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| codigo_transportista | integer | No | GENERATED ALWAYS AS IDENTITY |
| razon_social | character varying(150) | No | — |
| cuit | cuit_dom | No | — |
| email | character varying(100) | No | — |
| telefono | character varying(30) | No | — |
| domicilio | character varying(200) | No | — |

Restricciones:

- `transportista_codigo_transportista_not_null`: `NOT NULL codigo_transportista`.
- `transportista_cuit_not_null`: `NOT NULL cuit`.
- `transportista_domicilio_not_null`: `NOT NULL domicilio`.
- `transportista_email_not_null`: `NOT NULL email`.
- `transportista_razon_social_not_null`: `NOT NULL razon_social`.
- `transportista_telefono_not_null`: `NOT NULL telefono`.
- `transportista_pkey`: `PRIMARY KEY (codigo_transportista)`.
- `transportista_cuit_key`: `UNIQUE (cuit)`.
- `uq_transportista_email`: `UNIQUE (email)`.

## transportista_cobertura

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| codigo_transportista | integer | No | — |
| codigo_postal | character varying(10) | No | — |

Restricciones:

- `transportista_cobertura_codigo_postal_fkey`: `FOREIGN KEY (codigo_postal) REFERENCES localidad(codigo_postal) ON DELETE RESTRICT`.
- `transportista_cobertura_codigo_transportista_fkey`: `FOREIGN KEY (codigo_transportista) REFERENCES transportista(codigo_transportista) ON DELETE CASCADE`.
- `transportista_cobertura_codigo_postal_not_null`: `NOT NULL codigo_postal`.
- `transportista_cobertura_codigo_transportista_not_null`: `NOT NULL codigo_transportista`.
- `transportista_cobertura_pkey`: `PRIMARY KEY (codigo_transportista, codigo_postal)`.

## vino

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cod_vino | integer | No | GENERATED ALWAYS AS IDENTITY |
| nombre | character varying(100) | No | — |
| tipo | tipo_vino | No | — |
| anada | smallint | No | — |
| volumen_ml | integer | No | 750 |
| graduacion | numeric(4,2) | No | — |
| precio | numeric(10,2) | No | — |
| cuit_bodega | cuit_dom | No | — |

Restricciones:

- `chk_vino_graduacion`: `CHECK (((graduacion >= (5)::numeric) AND (graduacion <= (20)::numeric)))`.
- `chk_vino_precio_positivo`: `CHECK ((precio > (0)::numeric))`.
- `chk_vino_volumen_positivo`: `CHECK ((volumen_ml > 0))`.
- `vino_cuit_bodega_fkey`: `FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) ON DELETE RESTRICT`.
- `vino_anada_not_null`: `NOT NULL anada`.
- `vino_cod_vino_not_null`: `NOT NULL cod_vino`.
- `vino_cuit_bodega_not_null`: `NOT NULL cuit_bodega`.
- `vino_graduacion_not_null`: `NOT NULL graduacion`.
- `vino_nombre_not_null`: `NOT NULL nombre`.
- `vino_precio_not_null`: `NOT NULL precio`.
- `vino_tipo_not_null`: `NOT NULL tipo`.
- `vino_volumen_ml_not_null`: `NOT NULL volumen_ml`.
- `vino_pkey`: `PRIMARY KEY (cod_vino)`.
- `trg_validar_composicion_al_crear_vino`: `TRIGGER DEFERRABLE INITIALLY DEFERRED`.
- `uq_vino_bodega_nombre_anada_volumen`: `UNIQUE (cuit_bodega, nombre, anada, volumen_ml)`.

Triggers:

- `CREATE TRIGGER trg_auditar_precio_vino AFTER UPDATE OF precio ON public.vino FOR EACH ROW EXECUTE FUNCTION fn_trg_auditar_precio_vino()`.
- `CREATE CONSTRAINT TRIGGER trg_validar_composicion_al_crear_vino AFTER INSERT ON public.vino DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION fn_trg_validar_composicion_vino()`.

## vino_maridaje

| Columna | Tipo | Admite NULL | Predeterminado / identidad |
|---|---|---|---|
| cod_vino | integer | No | — |
| id_maridaje | integer | No | — |

Restricciones:

- `vino_maridaje_cod_vino_fkey`: `FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE CASCADE`.
- `vino_maridaje_id_maridaje_fkey`: `FOREIGN KEY (id_maridaje) REFERENCES maridaje(id_maridaje) ON DELETE RESTRICT`.
- `vino_maridaje_cod_vino_not_null`: `NOT NULL cod_vino`.
- `vino_maridaje_id_maridaje_not_null`: `NOT NULL id_maridaje`.
- `vino_maridaje_pkey`: `PRIMARY KEY (cod_vino, id_maridaje)`.

## Tipos enumerados

- estado_documento: en_confeccion, terminado, procesado.
- tipo_cepa: tinta, blanca.
- tipo_cliente_enum: socio, distribuidor, exportador.
- tipo_vino: tinto, blanco, rosado, espumante.

## Rutinas

| Firma | Resultado | Seguridad | Volatilidad |
|---|---|---|---|
| fn_antiguedad_anios(date) | integer | INVOKER | STABLE |
| fn_antiguedad_anios(date,date) | integer | INVOKER | IMMUTABLE |
| fn_calcular_descuento_cliente(integer,numeric) | numeric | INVOKER | STABLE |
| fn_descuento_cliente(integer) | numeric | INVOKER | STABLE |
| fn_stock_sala(integer,integer) | integer | INVOKER | STABLE |
| fn_total_comprobante(integer) | numeric | INVOKER | STABLE |
| fn_trg_aplicar_venta() | trigger | DEFINER | VOLATILE |
| fn_trg_auditar_precio_vino() | trigger | INVOKER | VOLATILE |
| fn_trg_bloquear_renglon_ingreso() | trigger | INVOKER | VOLATILE |
| fn_trg_bloquear_renglon_transferencia() | trigger | INVOKER | VOLATILE |
| fn_trg_calcular_renglon_venta() | trigger | DEFINER | VOLATILE |
| fn_trg_descuento_base_cliente() | trigger | INVOKER | VOLATILE |
| fn_trg_proteger_cabecera_documento() | trigger | INVOKER | VOLATILE |
| fn_trg_proteger_fecha_transferencia() | trigger | INVOKER | VOLATILE |
| fn_trg_validar_borrado_ingreso() | trigger | INVOKER | VOLATILE |
| fn_trg_validar_cantidad_comprobante() | trigger | INVOKER | VOLATILE |
| fn_trg_validar_composicion_vino() | trigger | INVOKER | VOLATILE |
| fn_trg_validar_stock_venta() | trigger | DEFINER | VOLATILE |
| fn_trg_validar_transicion_estado() | trigger | INVOKER | VOLATILE |
| sp_procesar_ingreso(integer) | procedimiento | DEFINER | VOLATILE |
| sp_procesar_transferencia(integer) | procedimiento | DEFINER | VOLATILE |
| sp_terminar_ingreso(integer) | procedimiento | DEFINER | VOLATILE |
| sp_terminar_transferencia(integer) | procedimiento | DEFINER | VOLATILE |
