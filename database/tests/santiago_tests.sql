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

DO $$ BEGIN
    ASSERT fn_descuento_cliente(-901) = .10, 'RN-06 socio';
    ASSERT fn_descuento_cliente(-902) = .20, 'RN-06 distribuidor';
    ASSERT fn_descuento_cliente(-903) = .30, 'RN-06 exportador';
    ASSERT fn_calcular_descuento_cliente(-901,10000) = 9000;
    ASSERT fn_calcular_descuento_cliente(-902,10000) = 8000;
    ASSERT fn_calcular_descuento_cliente(-903,10000) = 7000;
    ASSERT fn_calcular_descuento_cliente(-901,0.05) = 0.04, 'redondeo monetario';
    ASSERT fn_stock_sala(-901,-901) = 0;
    ASSERT fn_antiguedad_anios(DATE '2020-10-21',DATE '2025-10-20') = 4;
    ASSERT fn_antiguedad_anios(DATE '2020-10-21',DATE '2025-10-21') = 5;
    BEGIN PERFORM fn_descuento_cliente(-9999); RAISE EXCEPTION 'No rechazó cliente ausente';
    EXCEPTION WHEN no_data_found THEN NULL; END;
    BEGIN PERFORM fn_calcular_descuento_cliente(-901,-1); RAISE EXCEPTION 'No rechazó monto negativo';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END $$;
INSERT INTO ingreso(codigo_ingreso,codigo_transportista,cuit_bodega) OVERRIDING SYSTEM VALUE
VALUES (-901,-901,'99000000001'),(-902,-901,'99000000001'),(-903,-901,'99000000002');
INSERT INTO renglon_ingreso VALUES (-901,-903,10),(-901,-902,10),(-903,-901,10);
DO $$ BEGIN
    BEGIN CALL sp_procesar_ingreso(-901); RAISE EXCEPTION 'Aceptó en confección';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_ingreso(-9999); RAISE EXCEPTION 'Aceptó ingreso inexistente';
    EXCEPTION WHEN no_data_found THEN NULL; END;
END $$;
UPDATE ingreso SET estado='terminado' WHERE codigo_ingreso IN (-901,-902,-903);
CALL sp_procesar_ingreso(-901);
DO $$ BEGIN
    ASSERT (SELECT cantidad=10 FROM stock_deposito WHERE cod_vino=-903);
    ASSERT (SELECT estado='procesado' FROM ingreso WHERE codigo_ingreso=-901);
    BEGIN CALL sp_procesar_ingreso(-901); RAISE EXCEPTION 'Procesó ingreso dos veces';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_ingreso(-902); RAISE EXCEPTION 'Aceptó ingreso vacío';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_ingreso(-903); RAISE EXCEPTION 'Aceptó bodega incompatible';
    EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

INSERT INTO transferencia(numero_solicitud,id_sala) OVERRIDING SYSTEM VALUE
VALUES (-901,-901),(-902,-901),(-903,-901),(-904,-901);
-- -902: primer renglón se podría aplicar y segundo falla por falta de fila.
-- -903: segundo renglón falla por stock insuficiente.
INSERT INTO renglon_transferencia VALUES
(-901,-903,3),(-902,-903,2),(-902,-901,1),(-903,-903,2),(-903,-902,11);
DO $$ BEGIN
    BEGIN CALL sp_procesar_transferencia(-901); RAISE EXCEPTION 'Aceptó confección';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_transferencia(-9999); RAISE EXCEPTION 'Aceptó inexistente';
    EXCEPTION WHEN no_data_found THEN NULL; END;
END $$;
UPDATE transferencia SET estado='terminado' WHERE numero_solicitud IN (-901,-902,-903,-904);
CALL sp_procesar_transferencia(-901);
DO $$ BEGIN
    ASSERT (SELECT cantidad=7 FROM stock_deposito WHERE cod_vino=-903);
    ASSERT fn_stock_sala(-901,-903)=3;
    ASSERT (SELECT estado='procesado' FROM transferencia WHERE numero_solicitud=-901);
    BEGIN CALL sp_procesar_transferencia(-901); RAISE EXCEPTION 'Procesó dos veces';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_transferencia(-902); RAISE EXCEPTION 'Aceptó stock ausente';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_transferencia(-903); RAISE EXCEPTION 'Aceptó stock insuficiente';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN CALL sp_procesar_transferencia(-904); RAISE EXCEPTION 'Aceptó transferencia vacía';
    EXCEPTION WHEN check_violation THEN NULL; END;
    ASSERT (SELECT cantidad=7 FROM stock_deposito WHERE cod_vino=-903), 'rollback depósito';
    ASSERT fn_stock_sala(-901,-903)=3, 'rollback sala';
    ASSERT (SELECT estado='terminado' FROM transferencia WHERE numero_solicitud=-902);
    ASSERT (SELECT estado='terminado' FROM transferencia WHERE numero_solicitud=-903);
END $$;

-- Fixture S9: el runner comprobará que 2 cepas x 2 maridajes no multiplican stock.
INSERT INTO cepa(id_cepa,nombre,tipo) OVERRIDING SYSTEM VALUE VALUES
(-901,'STG Cepa A','blanca'),(-902,'STG Cepa B','blanca');
INSERT INTO composicion_vino VALUES (-903,-901,60),(-903,-902,40);
INSERT INTO maridaje(id_maridaje,nombre,temp_servicio_sugerida_c) OVERRIDING SYSTEM VALUE VALUES
(-901,'STG Maridaje A',8),(-902,'STG Maridaje B',10);
INSERT INTO vino_maridaje VALUES (-903,-901),(-903,-902);
INSERT INTO comprobante(numero_comprobante,id_cliente,id_sala) OVERRIDING SYSTEM VALUE
VALUES (-901,-901,-901),(-902,-903,-901);
INSERT INTO renglon_comprobante VALUES (-901,-903,1,100,10,90);
DO $$ BEGIN
    ASSERT fn_total_comprobante(-901)=90;
    ASSERT fn_total_comprobante(-902)=0;
    BEGIN PERFORM fn_total_comprobante(-9999); RAISE EXCEPTION 'Aceptó comprobante ausente';
    EXCEPTION WHEN no_data_found THEN NULL; END;
END $$;
ROLLBACK;
