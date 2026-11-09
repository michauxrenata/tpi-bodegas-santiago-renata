-- ============================================================================
-- BODEGAS DEL ATUEL - 005_TRIGGERS.SQL
-- Triggers de integridad y reglas de negocio - Etapa 2
-- ============================================================================


-- ============================================================================
-- RN-15: cantidades positivas en renglones de comprobantes
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_validar_cantidad_comprobante()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.cantidad <= 0 THEN
        RAISE EXCEPTION
            'RN-15: la cantidad del renglón del comprobante debe ser mayor que cero';
    END IF;

    RETURN NEW;
END;
$$;
-- RN-06: descuento base al insertar o cambiar el tipo de cliente.
-- Una actualizacion de descuento, como U6, conserva su valor
-- mientras el tipo de cliente no cambie.

CREATE OR REPLACE FUNCTION public.fn_trg_descuento_base_cliente()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_asignar_base BOOLEAN;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_asignar_base := TRUE;
    ELSE
        v_asignar_base :=
            NEW.tipo_cliente IS DISTINCT FROM OLD.tipo_cliente;
    END IF;

    IF v_asignar_base THEN
        NEW.descuento := CASE NEW.tipo_cliente
            WHEN 'socio' THEN 0.10
            WHEN 'distribuidor' THEN 0.20
            WHEN 'exportador' THEN 0.30
        END;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_descuento_base_cliente
ON public.cliente;

CREATE TRIGGER trg_descuento_base_cliente
BEFORE INSERT OR UPDATE OF tipo_cliente
ON public.cliente
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_descuento_base_cliente();

DROP TRIGGER IF EXISTS trg_validar_cantidad_comprobante
ON renglon_comprobante;

CREATE TRIGGER trg_validar_cantidad_comprobante
BEFORE INSERT OR UPDATE ON renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_cantidad_comprobante();


-- ============================================================================
-- RN-13: auditoría de cambios de precio
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_auditar_precio_vino()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.precio IS DISTINCT FROM OLD.precio THEN
        INSERT INTO auditoria_precio (
            cod_vino,
            precio_anterior,
            precio_nuevo,
            fecha_hora,
            usuario
        )
        VALUES (
            OLD.cod_vino,
            OLD.precio,
            NEW.precio,
            CURRENT_TIMESTAMP,
            CURRENT_USER
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditar_precio_vino
ON vino;

CREATE TRIGGER trg_auditar_precio_vino
AFTER UPDATE OF precio ON vino
FOR EACH ROW
EXECUTE FUNCTION fn_trg_auditar_precio_vino();


-- ============================================================================
-- RN-11: protección de la fecha de confección de transferencias
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_proteger_fecha_transferencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := CURRENT_DATE;
    ELSIF NEW.fecha_confeccion IS DISTINCT FROM OLD.fecha_confeccion THEN
        RAISE EXCEPTION
            'RN-11: la fecha de confección de una transferencia no puede modificarse';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_fecha_transferencia
ON transferencia;

CREATE TRIGGER trg_proteger_fecha_transferencia
BEFORE INSERT OR UPDATE OF fecha_confeccion ON transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_proteger_fecha_transferencia();


-- ============================================================================
-- RN-12: bloqueo de renglones de ingresos fuera de confección
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_trg_bloquear_renglon_ingreso()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_codigos INTEGER[];
    v_codigo INTEGER;
    v_estado public.estado_documento;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_codigos := ARRAY[NEW.codigo_ingreso];
    ELSIF TG_OP = 'DELETE' THEN
        v_codigos := ARRAY[OLD.codigo_ingreso];
    ELSE
        v_codigos := ARRAY[OLD.codigo_ingreso, NEW.codigo_ingreso];
    END IF;

    -- Si cambia de documento, validar ambos, en orden estable.
    FOR v_codigo IN
        SELECT DISTINCT u.codigo
        FROM unnest(v_codigos) AS u(codigo)
        ORDER BY u.codigo
    LOOP
        SELECT i.estado
        INTO v_estado
        FROM public.ingreso AS i
        WHERE i.codigo_ingreso = v_codigo
        FOR UPDATE;

        IF NOT FOUND THEN
            IF TG_OP = 'DELETE' THEN
                -- La FK mantiene la integridad: este caso permite
                -- la eliminacion de detalles por ON DELETE CASCADE.
                RETURN OLD;
            END IF;

            RAISE EXCEPTION 'Ingreso % inexistente', v_codigo
                USING ERRCODE = '23503';
        END IF;

        IF v_estado <> 'en_confeccion' THEN
            RAISE EXCEPTION
                'RN-12: el ingreso % no admite cambios de renglones',
                v_codigo
                USING ERRCODE = '23514';
        END IF;
    END LOOP;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloquear_renglon_ingreso
ON renglon_ingreso;

CREATE TRIGGER trg_bloquear_renglon_ingreso
BEFORE INSERT OR UPDATE OR DELETE ON renglon_ingreso
FOR EACH ROW
EXECUTE FUNCTION fn_trg_bloquear_renglon_ingreso();


-- ============================================================================
-- RN-12: bloqueo de renglones de transferencias fuera de confección
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_trg_bloquear_renglon_transferencia()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_numeros INTEGER[];
    v_numero INTEGER;
    v_estado public.estado_documento;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_numeros := ARRAY[NEW.numero_solicitud];
    ELSIF TG_OP = 'DELETE' THEN
        v_numeros := ARRAY[OLD.numero_solicitud];
    ELSE
        v_numeros := ARRAY[
            OLD.numero_solicitud,
            NEW.numero_solicitud
        ];
    END IF;

    FOR v_numero IN
        SELECT DISTINCT u.numero
        FROM unnest(v_numeros) AS u(numero)
        ORDER BY u.numero
    LOOP
        SELECT t.estado
        INTO v_estado
        FROM public.transferencia AS t
        WHERE t.numero_solicitud = v_numero
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Transferencia % inexistente', v_numero
                USING ERRCODE = '23503';
        END IF;

        IF v_estado <> 'en_confeccion' THEN
            RAISE EXCEPTION
                'RN-12: la transferencia % no admite cambios de renglones',
                v_numero
                USING ERRCODE = '23514';
        END IF;
    END LOOP;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloquear_renglon_transferencia
ON renglon_transferencia;

CREATE TRIGGER trg_bloquear_renglon_transferencia
BEFORE INSERT OR UPDATE OR DELETE ON renglon_transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_bloquear_renglon_transferencia();


-- ============================================================================
-- RN-10 y RN-11: control de transición de estados
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_validar_transicion_estado()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN
        RETURN NEW;
    END IF;

    IF NOT (
        OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado'
        OR
        OLD.estado = 'terminado' AND NEW.estado = 'procesado'
    ) THEN
        RAISE EXCEPTION
            'RN-10/RN-11: transición de estado no permitida: % -> %',
            OLD.estado,
            NEW.estado;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_estado_ingreso
ON ingreso;

CREATE TRIGGER trg_validar_estado_ingreso
BEFORE UPDATE OF estado ON ingreso
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_transicion_estado();

DROP TRIGGER IF EXISTS trg_validar_estado_transferencia
ON transferencia;

CREATE TRIGGER trg_validar_estado_transferencia
BEFORE UPDATE OF estado ON transferencia
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_transicion_estado();


-- ============================================================================
-- RN-05: composición de cada vino exactamente igual al 100 %
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_trg_validar_composicion_vino()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_codigos INTEGER[];
    v_cod_vino INTEGER;
    v_total NUMERIC;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_codigos := ARRAY[NEW.cod_vino];
    ELSIF TG_OP = 'DELETE' THEN
        v_codigos := ARRAY[OLD.cod_vino];
    ELSE
        v_codigos := ARRAY[OLD.cod_vino, NEW.cod_vino];
    END IF;

    FOR v_cod_vino IN
        SELECT DISTINCT u.codigo
        FROM unnest(v_codigos) AS u(codigo)
        WHERE u.codigo IS NOT NULL
        ORDER BY u.codigo
    LOOP
        -- Si el vino fue eliminado, no exigir su composicion.
        IF NOT EXISTS (
            SELECT 1
            FROM public.vino AS v
            WHERE v.cod_vino = v_cod_vino
        ) THEN
            CONTINUE;
        END IF;

        SELECT COALESCE(SUM(c.porcentaje), 0)
        INTO v_total
        FROM public.composicion_vino AS c
        WHERE c.cod_vino = v_cod_vino;

        IF v_total IS DISTINCT FROM 100::NUMERIC THEN
            RAISE EXCEPTION
                'RN-05: la composicion del vino % debe sumar 100%% y actualmente suma %',
                v_cod_vino, v_total
                USING ERRCODE = '23514';
        END IF;
    END LOOP;

    -- El valor retornado no se utiliza en triggers AFTER.
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_composicion_al_crear_vino ON public.vino;

-- Detecta vinos nuevos incluso si no se insertaron componentes.
CREATE CONSTRAINT TRIGGER trg_validar_composicion_al_crear_vino
AFTER INSERT ON public.vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_validar_composicion_vino();

DROP TRIGGER IF EXISTS trg_validar_composicion_vino
ON composicion_vino;

CREATE CONSTRAINT TRIGGER trg_validar_composicion_vino
AFTER INSERT OR UPDATE OR DELETE ON composicion_vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_composicion_vino();
-- Venta nueva: precio historico e importes calculados por la BD.
-- Solo INSERT: no reescribe ventas anteriores ni interfiere con U1.

CREATE OR REPLACE FUNCTION public.fn_trg_calcular_renglon_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_id_cliente INTEGER;
    v_precio NUMERIC;
    v_tasa NUMERIC;
    v_bruto NUMERIC;
BEGIN
    IF NEW.cantidad IS NULL OR NEW.cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero'
            USING ERRCODE = '23514';
    END IF;

    -- Serializa la incorporacion de renglones al mismo comprobante.
    SELECT c.id_cliente
    INTO v_id_cliente
    FROM public.comprobante AS c
    WHERE c.numero_comprobante = NEW.numero_comprobante
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Comprobante % inexistente',
            NEW.numero_comprobante
            USING ERRCODE = '23503';
    END IF;

    SELECT v.precio
    INTO v_precio
    FROM public.vino AS v
    WHERE v.cod_vino = NEW.cod_vino;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vino % inexistente', NEW.cod_vino
            USING ERRCODE = '23503';
    END IF;

    v_tasa := public.fn_descuento_cliente(v_id_cliente);

    NEW.precio_unitario := v_precio;
    v_bruto := ROUND(NEW.cantidad::NUMERIC * NEW.precio_unitario, 2);
    NEW.descuento := ROUND(v_bruto * v_tasa, 2);
    NEW.subtotal := v_bruto - NEW.descuento;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_trg_calcular_renglon_venta()
FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_calcular_renglon_venta
ON public.renglon_comprobante;

CREATE TRIGGER trg_calcular_renglon_venta
BEFORE INSERT ON public.renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_calcular_renglon_venta();
-- Se ejecuta solamente cuando el renglon fue insertado.
-- Si no hay stock, se revierte la sentencia completa.

CREATE OR REPLACE FUNCTION public.fn_trg_aplicar_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_id_sala INTEGER;
    v_bruto NUMERIC;
BEGIN
    SELECT c.id_sala
    INTO v_id_sala
    FROM public.comprobante AS c
    WHERE c.numero_comprobante = NEW.numero_comprobante
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Comprobante % inexistente',
            NEW.numero_comprobante
            USING ERRCODE = '23503';
    END IF;

    -- Actualizacion atomica: dos ventas no pueden consumir
    -- simultaneamente las mismas existencias.
    UPDATE public.stock_sala
    SET cantidad = cantidad - NEW.cantidad
    WHERE id_sala = v_id_sala
      AND cod_vino = NEW.cod_vino
      AND cantidad >= NEW.cantidad;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Stock insuficiente para el vino % en la sala %',
            NEW.cod_vino, v_id_sala
            USING ERRCODE = '23514';
    END IF;

    v_bruto := ROUND(
        NEW.cantidad::NUMERIC * NEW.precio_unitario, 2
    );

    UPDATE public.comprobante
    SET subtotal = subtotal + v_bruto,
        descuento = descuento + NEW.descuento,
        total = total + NEW.subtotal
    WHERE numero_comprobante = NEW.numero_comprobante;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_trg_aplicar_venta()
FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_aplicar_venta
ON public.renglon_comprobante;

CREATE TRIGGER trg_aplicar_venta
AFTER INSERT ON public.renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_aplicar_venta();
-- RN-09: validar y bloquear stock antes de insertar la venta.
-- El AFTER INSERT realiza el descuento efectivo.

CREATE OR REPLACE FUNCTION public.fn_trg_validar_stock_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_disponible INTEGER;
BEGIN
    SELECT s.cantidad
    INTO v_disponible
    FROM public.comprobante AS c
    JOIN public.stock_sala AS s
      ON s.id_sala = c.id_sala
     AND s.cod_vino = NEW.cod_vino
    WHERE c.numero_comprobante = NEW.numero_comprobante
    FOR UPDATE OF s;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe stock de sala para el vino % y comprobante %',
            NEW.cod_vino, NEW.numero_comprobante
            USING ERRCODE = '23514';
    END IF;

    IF v_disponible < NEW.cantidad THEN
        RAISE EXCEPTION
            'Stock insuficiente del vino %: disponible %, solicitado %',
            NEW.cod_vino, v_disponible, NEW.cantidad
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_trg_validar_stock_venta()
FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_validar_stock_venta
ON public.renglon_comprobante;

CREATE TRIGGER trg_validar_stock_venta
BEFORE INSERT ON public.renglon_comprobante
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_validar_stock_venta();
-- RN-12: proteger detalles y permitir el borrado en cascada
-- cuando la cabecera fue eliminada mediante una operacion autorizada.


-- D5: depuracion historica; no revierte movimientos de stock.
CREATE OR REPLACE FUNCTION public.fn_trg_validar_borrado_ingreso()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF OLD.estado = 'en_confeccion' THEN
        RETURN OLD;
    END IF;

    IF OLD.estado = 'procesado'
       AND OLD.fecha < CURRENT_DATE - 365 THEN
        RETURN OLD;
    END IF;

    RAISE EXCEPTION
        'Solo se pueden borrar ingresos en confeccion o procesados de hace mas de 365 dias'
        USING ERRCODE = '23514';
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_borrado_ingreso
ON public.ingreso;

CREATE TRIGGER trg_validar_borrado_ingreso
BEFORE DELETE ON public.ingreso
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_validar_borrado_ingreso();

REVOKE ALL ON FUNCTION public.fn_trg_validar_borrado_ingreso()
FROM PUBLIC;