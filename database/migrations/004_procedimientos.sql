-- Propiedad y GRANT se configuran en 007_roles.sql por Valentina.
-- El propietario debe ser NOLOGIN, no superusuario; la API no debe ser miembro.
-- Tablas calificadas explícitamente; search_path excluye esquemas de aplicación.
-- Santiago · RN-10/RN-11. CALL participa en la transacción del invocador.
-- Sin COMMIT interno ni excepciones silenciadas: cualquier error revierte el CALL.
-- Protección transitoria ante RN-12 aún ausente: SHARE bloquea escrituras de
-- renglones durante el procesamiento. Es global por tabla (ver docs/contratos_datos.md).
CREATE OR REPLACE PROCEDURE public.sp_procesar_ingreso(p_codigo INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_ingreso public.ingreso%ROWTYPE; r RECORD;
BEGIN
    LOCK TABLE public.renglon_ingreso IN SHARE MODE;
    SELECT * INTO v_ingreso FROM public.ingreso WHERE codigo_ingreso = p_codigo FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ingreso % inexistente', p_codigo USING ERRCODE = 'P0002';
    END IF;
    IF v_ingreso.estado <> 'terminado' THEN
        RAISE EXCEPTION 'RN-10: public.ingreso % debe estar terminado', p_codigo USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT FROM public.renglon_ingreso WHERE codigo_ingreso = p_codigo) THEN
        RAISE EXCEPTION 'Ingreso sin renglones' USING ERRCODE = '23514';
    END IF;
    FOR r IN SELECT ri.*, v.cuit_bodega FROM public.renglon_ingreso ri
             JOIN public.vino v USING (cod_vino) WHERE codigo_ingreso = p_codigo ORDER BY cod_vino
    LOOP
        IF r.cantidad <= 0 OR r.cuit_bodega <> v_ingreso.cuit_bodega THEN
            RAISE EXCEPTION 'Cantidad inválida o bodega incompatible para public.vino %', r.cod_vino USING ERRCODE = '23514';
        END IF;
        INSERT INTO public.stock_deposito(cod_vino, cantidad) VALUES (r.cod_vino, r.cantidad)
        ON CONFLICT(cod_vino) DO UPDATE
          SET cantidad = public.stock_deposito.cantidad + EXCLUDED.cantidad;
    END LOOP;
    UPDATE public.ingreso SET estado = 'procesado' WHERE codigo_ingreso = p_codigo;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_procesar_transferencia(p_numero INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_transferencia public.transferencia%ROWTYPE; r RECORD; v_stock INTEGER;
BEGIN
    LOCK TABLE public.renglon_transferencia IN SHARE MODE;
    SELECT * INTO v_transferencia FROM public.transferencia
    WHERE numero_solicitud = p_numero FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % inexistente', p_numero USING ERRCODE = 'P0002';
    END IF;
    IF v_transferencia.estado <> 'terminado' THEN
        RAISE EXCEPTION 'RN-11: public.transferencia % debe estar terminada', p_numero USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT FROM public.renglon_transferencia WHERE numero_solicitud = p_numero) THEN
        RAISE EXCEPTION 'Transferencia sin renglones' USING ERRCODE = '23514';
    END IF;
    -- Orden común de vinos reduce deadlocks entre documentos con varios renglones.
    FOR r IN SELECT * FROM public.renglon_transferencia
             WHERE numero_solicitud = p_numero ORDER BY cod_vino
    LOOP
        IF r.cantidad <= 0 THEN
            RAISE EXCEPTION 'Cantidad inválida para public.vino %', r.cod_vino USING ERRCODE = '23514';
        END IF;
        SELECT cantidad INTO v_stock FROM public.stock_deposito
        WHERE cod_vino = r.cod_vino FOR UPDATE;
        IF NOT FOUND OR v_stock < r.cantidad THEN
            RAISE EXCEPTION 'RN-11: stock de depósito ausente o insuficiente para public.vino %', r.cod_vino
              USING ERRCODE = '23514';
        END IF;
        UPDATE public.stock_deposito SET cantidad = cantidad - r.cantidad WHERE cod_vino = r.cod_vino;
        INSERT INTO public.stock_sala(id_sala, cod_vino, cantidad)
        VALUES (v_transferencia.id_sala, r.cod_vino, r.cantidad)
        ON CONFLICT(id_sala, cod_vino) DO UPDATE
          SET cantidad = public.stock_sala.cantidad + EXCLUDED.cantidad;
    END LOOP;
    UPDATE public.transferencia SET estado = 'procesado' WHERE numero_solicitud = p_numero;
END;
$$;

-- No dejar las rutinas nuevas ejecutables por cualquier usuario.
REVOKE ALL ON PROCEDURE public.sp_procesar_ingreso(INTEGER) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_procesar_transferencia(INTEGER) FROM PUBLIC;

-- Cierre de confección: valida el documento y cambia sólo su estado.
-- No reserva ni mueve stock. La disponibilidad se comprueba al procesar.
-- Mantiene el orden de bloqueo de sp_procesar_*: tabla de detalles, cabecera.
CREATE OR REPLACE PROCEDURE public.sp_terminar_ingreso(p_codigo INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_ingreso public.ingreso%ROWTYPE;
BEGIN
    LOCK TABLE public.renglon_ingreso IN SHARE MODE;
    SELECT * INTO v_ingreso FROM public.ingreso
    WHERE codigo_ingreso = p_codigo FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ingreso % inexistente', p_codigo USING ERRCODE = 'P0002';
    END IF;
    IF v_ingreso.estado <> 'en_confeccion' THEN
        RAISE EXCEPTION 'Ingreso % debe estar en confección', p_codigo USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT FROM public.renglon_ingreso WHERE codigo_ingreso = p_codigo) THEN
        RAISE EXCEPTION 'Ingreso sin renglones' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT FROM public.renglon_ingreso ri JOIN public.vino v USING (cod_vino)
        WHERE ri.codigo_ingreso = p_codigo
        AND (ri.cantidad <= 0 OR v.cuit_bodega <> v_ingreso.cuit_bodega)
    ) THEN
        RAISE EXCEPTION 'Cantidad inválida o bodega incompatible en ingreso %', p_codigo
            USING ERRCODE = '23514';
    END IF;
    UPDATE public.ingreso SET estado = 'terminado' WHERE codigo_ingreso = p_codigo;
END;
$$;

CREATE OR REPLACE PROCEDURE public.sp_terminar_transferencia(p_numero INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE v_transferencia public.transferencia%ROWTYPE;
BEGIN
    LOCK TABLE public.renglon_transferencia IN SHARE MODE;
    SELECT * INTO v_transferencia FROM public.transferencia
    WHERE numero_solicitud = p_numero FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % inexistente', p_numero USING ERRCODE = 'P0002';
    END IF;
    IF v_transferencia.estado <> 'en_confeccion' THEN
        RAISE EXCEPTION 'Transferencia % debe estar en confección', p_numero USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT FROM public.renglon_transferencia WHERE numero_solicitud = p_numero) THEN
        RAISE EXCEPTION 'Transferencia sin renglones' USING ERRCODE = '23514';
    END IF;
    IF EXISTS (SELECT FROM public.renglon_transferencia
        WHERE numero_solicitud = p_numero AND cantidad <= 0) THEN
        RAISE EXCEPTION 'Cantidad inválida en transferencia %', p_numero USING ERRCODE = '23514';
    END IF;
    UPDATE public.transferencia SET estado = 'terminado' WHERE numero_solicitud = p_numero;
END;
$$;

REVOKE ALL ON PROCEDURE public.sp_terminar_ingreso(INTEGER) FROM PUBLIC;
REVOKE ALL ON PROCEDURE public.sp_terminar_transferencia(INTEGER) FROM PUBLIC;
