-- Se usa después del fixture de santiago_tests, sólo en base descartable.
INSERT INTO finca(id_finca,nombre,superficie_ha,departamento,provincia) OVERRIDING SYSTEM VALUE
VALUES (-901,'Prueba',6,'San Rafael','Mendoza');
INSERT INTO parcela VALUES (-901,1,2,2000,-901),(-901,2,4,2000,-902);
INSERT INTO lote_uva(id_finca,nro_parcela,campana,fecha_cosecha,kg_cosechados,cuit_bodega_destino)
VALUES (-901,1,2024,'2024-03-01',200,'99000000001'),
       (-901,2,2024,'2024-03-01',800,'99000000001'),
       (-901,1,2025,'2025-03-01',2000,'99000000001');
INSERT INTO comprobante(numero_comprobante,fecha,id_cliente,id_sala,subtotal,descuento,total)
OVERRIDING SYSTEM VALUE VALUES
(-903,'2024-01-10',-903,-901,800,280,520),
(-904,'2024-02-10',-901,-901,400,40,360);
INSERT INTO renglon_comprobante VALUES
(-903,-903,2,100,70,130),(-903,-902,2,200,140,260),(-903,-901,2,100,70,130),
(-904,-902,2,200,40,360);
INSERT INTO permiso_exportacion VALUES
('STG-P1',-903,'2024-01-01','2025-01-01'),('STG-P2',-903,'2024-01-01','2025-01-01'),
('STG-P3',-903,'2024-01-01','2025-01-01'),('STG-P4',-903,'2024-01-01','2025-01-01');
INSERT INTO empleado VALUES
('99000000011','Exactamente cinco',(CURRENT_DATE-INTERVAL '5 years')::date,1000,-901),
('99000000012','Cinco y un día',(CURRENT_DATE-INTERVAL '5 years')::date-1,1000,-901);
