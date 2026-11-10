-- Complemento H6. Ejecutar despues de 001-008 como administrador.
-- No amplia los permisos de rol_operador_ventas para otros usuarios.
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='rol_api_catalogos') THEN
 CREATE ROLE rol_api_catalogos NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
 END IF;
END $$;
GRANT USAGE ON SCHEMA public TO rol_api_catalogos;
GRANT SELECT ON public.vino,public.composicion_vino,public.vino_maridaje,
 public.cliente,public.cliente_socio,public.cliente_distribuidor,public.cliente_exportador,
 public.cepa,public.maridaje,public.bodega,public.parcela,public.lote_uva,
 public.auditoria_precio,public.vw_stock_total_vinos TO rol_api_catalogos;
GRANT INSERT(nombre,tipo,anada,volumen_ml,graduacion,precio,cuit_bodega),
 UPDATE(nombre,tipo,anada,volumen_ml,graduacion,precio,cuit_bodega),DELETE ON public.vino TO rol_api_catalogos;
GRANT INSERT,DELETE ON public.composicion_vino,public.vino_maridaje TO rol_api_catalogos;
GRANT INSERT(nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente),
 UPDATE(nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente),DELETE
 ON public.cliente TO rol_api_catalogos;
GRANT INSERT,UPDATE,DELETE ON public.cliente_socio,public.cliente_distribuidor,public.cliente_exportador TO rol_api_catalogos;
-- Trigger de tasas base modifica NEW.descuento sin requerir UPDATE del usuario.
-- Trigger de auditoria vigente es invoker: necesita INSERT/USAGE de auditoria.
GRANT INSERT ON public.auditoria_precio TO rol_api_catalogos;
GRANT USAGE ON SEQUENCE public.vino_cod_vino_seq,public.cliente_id_cliente_seq,
 public.auditoria_precio_id_auditoria_seq TO rol_api_catalogos;
