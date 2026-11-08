-- SOLO base vacía de benchmark. Dataset determinista, NO entrega H3.
-- Sin ventas reales ni stock: enfocado en selectividad de cabeceras y transferencias.
INSERT INTO localidad VALUES ('BENCH','Benchmark','Mendoza','Prueba');
INSERT INTO bodega VALUES ('98000000001','Benchmark','Prueba');
INSERT INTO vino(cod_vino,nombre,tipo,anada,volumen_ml,graduacion,precio,cuit_bodega)
OVERRIDING SYSTEM VALUE VALUES (1,'Benchmark','tinto',2024,750,14,100,'98000000001');
INSERT INTO sala_venta(id_sala,calle,numero,dia_cierre,codigo_postal) OVERRIDING SYSTEM VALUE
SELECT g,'Prueba',g::text,'lunes','BENCH' FROM generate_series(1,30) g;
INSERT INTO cliente(id_cliente,nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente)
OVERRIDING SYSTEM VALUE VALUES (1,'Benchmark','TEST','BENCH','Prueba','Benchmark','socio');
INSERT INTO cliente_socio VALUES (1);
INSERT INTO comprobante(numero_comprobante,fecha,id_cliente,id_sala,subtotal,descuento,total)
OVERRIDING SYSTEM VALUE
SELECT g,CURRENT_DATE - (g % 3650),1,1+(g%30),100,10,90
FROM generate_series(1,150000) g;
INSERT INTO transferencia(numero_solicitud,id_sala,fecha_confeccion,estado) OVERRIDING SYSTEM VALUE
SELECT g,1+(g%30),CURRENT_DATE - (g%3650),
       CASE WHEN g%100=0 THEN 'terminado' ELSE 'procesado' END::estado_documento
FROM generate_series(1,150000) g;
INSERT INTO renglon_transferencia SELECT g,1,1+(g%20) FROM generate_series(1,150000) g;
ANALYZE;
