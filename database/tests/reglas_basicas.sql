\set ON_ERROR_STOP on
-- Complemento RN-01/02/03/04/07/11/13/14/15. Base QA vacia.
-- Base de pruebas solamente. IDs negativos reservados; cualquier colisión falla.
-- Transacción con ROLLBACK: no deja los datos de prueba.
BEGIN;
INSERT INTO bodega VALUES ('99000000001','Prueba Santiago','Prueba'), ('99000000002','Otra','Prueba');
INSERT INTO localidad VALUES ('TEST-STG','Prueba','Mendoza','Responsable');
INSERT INTO sala_venta (id_sala,calle,numero,dia_cierre,codigo_postal) OVERRIDING SYSTEM VALUE
VALUES (-901,'Prueba','1','lunes','TEST-STG');
INSERT INTO transportista(codigo_transportista,razon_social,cuit,email,telefono,domicilio) OVERRIDING SYSTEM VALUE
VALUES (-901,'Prueba','99000000003','prueba@example.invalid','0','Prueba');
INSERT INTO vino(cod_vino,nombre,tipo,anada,volumen_ml,graduacion,precio,cuit_bodega) OVERRIDING SYSTEM VALUE
VALUES (-903,'Tercero','blanco',2024,750,12,100,'99000000001'),
       (-902,'Segundo','tinto',2024,750,14,200,'99000000001'),
       (-901,'Primero','tinto',2024,750,14,100,'99000000001');
INSERT INTO cliente(id_cliente,nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente,descuento) OVERRIDING SYSTEM VALUE
VALUES (-901,'Socio','TEST','STG1','Prueba','Prueba','socio',0.10),
       (-902,'Distribuidor','TEST','STG2','Prueba','Prueba','distribuidor',0.20),
       (-903,'Exportador','TEST','STG3','Prueba','Prueba','exportador',0.30);
INSERT INTO cliente_socio VALUES (-901);
INSERT INTO cliente_distribuidor VALUES (-902,'Prueba','STG-HABILITACION');
INSERT INTO cliente_exportador VALUES (-903,'Chile');


INSERT INTO cepa(id_cepa,nombre,tipo) OVERRIDING SYSTEM VALUE
VALUES(-901,'RN Cepa blanca','blanca'),(-902,'RN Cepa tinta','tinta');
INSERT INTO composicion_vino VALUES(-903,-901,100),(-902,-902,100),(-901,-902,100);
INSERT INTO finca(id_finca,nombre,superficie_ha,departamento,provincia) OVERRIDING SYSTEM VALUE
VALUES(-901,'RN Finca',10,'San Rafael','Mendoza');
INSERT INTO parcela VALUES(-901,1,5,2000,-901);
INSERT INTO lote_uva(nro_lote,id_finca,nro_parcela,campana,fecha_cosecha,kg_cosechados,cuit_bodega_destino)
OVERRIDING SYSTEM VALUE VALUES(-901,-901,1,2024,'2024-03-01',100,'99000000001');
INSERT INTO empleado VALUES('99000000011','RN Empleado',CURRENT_DATE,1000,-901);
INSERT INTO permiso_exportacion VALUES('RN-P1',-903,'2024-01-01','2025-01-01'),('RN-P2',-903,'2025-01-01','2026-01-01');
INSERT INTO ingreso(codigo_ingreso,codigo_transportista,cuit_bodega) OVERRIDING SYSTEM VALUE
VALUES(-901,-901,'99000000001');
INSERT INTO renglon_ingreso VALUES(-901,-903,5);
INSERT INTO transferencia(numero_solicitud,id_sala,fecha_confeccion) OVERRIDING SYSTEM VALUE
VALUES(-901,-901,CURRENT_DATE-10);
INSERT INTO renglon_transferencia VALUES(-901,-903,1);
INSERT INTO stock_deposito VALUES(-903,0);
INSERT INTO stock_sala VALUES(-901,-903,0);
SET CONSTRAINTS ALL IMMEDIATE;

-- Cada sentencia debe fallar con el SQLSTATE indicado. Si funciona, falla la prueba.
-- Los errores esperados revierten su propia subtransaccion.
CREATE FUNCTION pg_temp.esperar_error(etiqueta text, sentencia text, esperado text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE recibido text;
BEGIN
    BEGIN
        EXECUTE sentencia;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS recibido = RETURNED_SQLSTATE;
    END;
       IF NOT (
        recibido IS NOT DISTINCT FROM esperado
        OR (
            etiqueta LIKE 'RN-14 %'
            AND COALESCE(recibido IN ('23001', '23503'), FALSE)
        )
    ) THEN
        RAISE EXCEPTION 'FALLO %: esperado %, recibido %', etiqueta, esperado, COALESCE(recibido,'sin error');
    END IF;
    RAISE NOTICE 'OK %: rechazo %', etiqueta, recibido;
END;
$$;
SELECT pg_temp.esperar_error('RN-01 precio cero', $caso$UPDATE vino SET precio=0 WHERE cod_vino=-903$caso$, '23514');
SELECT pg_temp.esperar_error('RN-01 precio negativo', $caso$UPDATE vino SET precio=-1 WHERE cod_vino=-903$caso$, '23514');
SELECT pg_temp.esperar_error('RN-02 localidad ausente', $caso$UPDATE sala_venta SET codigo_postal='NO-EXISTE' WHERE id_sala=-901$caso$, '23503');
SELECT pg_temp.esperar_error('RN-02 localidad obligatoria', $caso$UPDATE sala_venta SET codigo_postal=NULL WHERE id_sala=-901$caso$, '23502');
SELECT pg_temp.esperar_error('RN-02 encargado obligatorio', $caso$UPDATE localidad SET encargado_regional=NULL WHERE codigo_postal='TEST-STG'$caso$, '23502');
SELECT pg_temp.esperar_error('RN-03 sala ausente', $caso$UPDATE empleado SET id_sala=-999999$caso$, '23503');
SELECT pg_temp.esperar_error('RN-03 sala obligatoria', $caso$UPDATE empleado SET id_sala=NULL$caso$, '23502');
SELECT pg_temp.esperar_error('RN-04 cepa ausente', $caso$UPDATE parcela SET id_cepa=-999999$caso$, '23503');
SELECT pg_temp.esperar_error('RN-04 cepa obligatoria', $caso$UPDATE parcela SET id_cepa=NULL$caso$, '23502');
SELECT pg_temp.esperar_error('RN-04 cosecha repetida', $caso$INSERT INTO lote_uva(id_finca,nro_parcela,campana,fecha_cosecha,kg_cosechados,cuit_bodega_destino) VALUES(-901,1,2024,'2024-04-01',100,'99000000001')$caso$, '23505');
SELECT pg_temp.esperar_error('RN-07 fechas iguales', $caso$UPDATE permiso_exportacion SET fecha_vencimiento=fecha_emision WHERE cod_permiso='RN-P1'$caso$, '23514');
SELECT pg_temp.esperar_error('RN-07 vencimiento anterior', $caso$UPDATE permiso_exportacion SET fecha_vencimiento=fecha_emision-1 WHERE cod_permiso='RN-P1'$caso$, '23514');
SELECT pg_temp.esperar_error('RN-11 fecha inmutable', $caso$UPDATE transferencia SET fecha_confeccion=CURRENT_DATE-1 WHERE numero_solicitud=-901$caso$, 'P0001');
SELECT pg_temp.esperar_error('RN-14 transportista con ingreso', $caso$DELETE FROM transportista WHERE codigo_transportista=-901$caso$, '23001');
SELECT pg_temp.esperar_error('RN-14 bodega con movimientos', $caso$DELETE FROM bodega WHERE cuit='99000000001'$caso$, '23001');
SELECT pg_temp.esperar_error('RN-14 vino con movimientos', $caso$DELETE FROM vino WHERE cod_vino=-903$caso$, '23001');
SELECT pg_temp.esperar_error('RN-15 superficie finca cero', $caso$UPDATE finca SET superficie_ha=0$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 superficie parcela negativa', $caso$UPDATE parcela SET superficie_ha=-1$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 kilos cero', $caso$UPDATE lote_uva SET kg_cosechados=0$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 cantidad ingreso cero', $caso$UPDATE renglon_ingreso SET cantidad=0$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 cantidad transferencia negativa', $caso$UPDATE renglon_transferencia SET cantidad=-1$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 volumen cero', $caso$UPDATE vino SET volumen_ml=0 WHERE cod_vino=-903$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 graduacion menor a 5', $caso$UPDATE vino SET graduacion=4.99 WHERE cod_vino=-903$caso$, '23514');
SELECT pg_temp.esperar_error('RN-15 graduacion mayor a 20', $caso$UPDATE vino SET graduacion=20.01 WHERE cod_vino=-903$caso$, '23514');
SELECT pg_temp.esperar_error('RN-09 stock deposito negativo', $caso$UPDATE stock_deposito SET cantidad=-1$caso$, '23514');
SELECT pg_temp.esperar_error('RN-09 stock sala negativo', $caso$UPDATE stock_sala SET cantidad=-1$caso$, '23514');

-- Casos validos y auditoria RN-13: cambio real, usuario, fecha e idempotencia.
UPDATE vino SET graduacion=5 WHERE cod_vino=-903;
UPDATE vino SET graduacion=20 WHERE cod_vino=-903;
UPDATE vino SET precio=125 WHERE cod_vino=-903;
UPDATE vino SET precio=125 WHERE cod_vino=-903;
DO $$ BEGIN
    IF (SELECT COUNT(*) FROM auditoria_precio WHERE cod_vino=-903) <> 1 THEN
        RAISE EXCEPTION 'RN-13: cantidad incorrecta de registros de auditoria';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM auditoria_precio WHERE cod_vino=-903
        AND precio_anterior=100 AND precio_nuevo=125
        AND usuario=CURRENT_USER AND fecha_hora=CURRENT_TIMESTAMP) THEN
        RAISE EXCEPTION 'RN-13: faltan valores correctos de precio, fecha o usuario';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM transferencia WHERE numero_solicitud=-901 AND fecha_confeccion=CURRENT_DATE) THEN
        RAISE EXCEPTION 'RN-11: la fecha inicial no fue forzada a hoy';
    END IF;
    RAISE NOTICE 'OK RN-13: auditoria completa; repetir precio no genera otro cambio';
    RAISE NOTICE 'OK RN-11: fecha inicial actual; RN-15: limites 5 y 20 aceptados';
END $$;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
