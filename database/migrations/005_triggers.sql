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

CREATE OR REPLACE FUNCTION fn_trg_bloquear_renglon_ingreso()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo_ingreso INTEGER;
    v_estado estado_documento;
BEGIN
    v_codigo_ingreso := CASE
        WHEN TG_OP = 'DELETE' THEN OLD.codigo_ingreso
        ELSE NEW.codigo_ingreso
    END;

    SELECT estado
    INTO v_estado
    FROM ingreso
    WHERE codigo_ingreso = v_codigo_ingreso;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe el ingreso asociado al renglón';
    END IF;

    IF v_estado <> 'en_confeccion' THEN
        RAISE EXCEPTION
            'RN-12: no se pueden modificar renglones de un ingreso que no está en confección';
    END IF;

    RETURN CASE
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
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

CREATE OR REPLACE FUNCTION fn_trg_bloquear_renglon_transferencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_numero_solicitud INTEGER;
    v_estado estado_documento;
BEGIN
    v_numero_solicitud := CASE
        WHEN TG_OP = 'DELETE' THEN OLD.numero_solicitud
        ELSE NEW.numero_solicitud
    END;

    SELECT estado
    INTO v_estado
    FROM transferencia
    WHERE numero_solicitud = v_numero_solicitud;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe la transferencia asociada al renglón';
    END IF;

    IF v_estado <> 'en_confeccion' THEN
        RAISE EXCEPTION
            'RN-12: no se pueden modificar renglones de una transferencia que no está en confección';
    END IF;

    RETURN CASE
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
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

CREATE OR REPLACE FUNCTION fn_trg_validar_composicion_vino()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cod_vino INTEGER;
    v_total NUMERIC;
BEGIN
    FOR v_cod_vino IN
        SELECT DISTINCT cod_vino
        FROM (
            SELECT CASE
                WHEN TG_OP <> 'INSERT' THEN OLD.cod_vino
            END AS cod_vino

            UNION ALL

            SELECT CASE
                WHEN TG_OP <> 'DELETE' THEN NEW.cod_vino
            END AS cod_vino
        ) vinos_afectados
        WHERE cod_vino IS NOT NULL
    LOOP
        SELECT COALESCE(SUM(porcentaje), 0)
        INTO v_total
        FROM composicion_vino
        WHERE cod_vino = v_cod_vino;

        IF v_total IS DISTINCT FROM 100::NUMERIC THEN
            RAISE EXCEPTION
                'RN-05: la composición del vino % debe sumar 100%% y actualmente suma %',
                v_cod_vino,
                v_total;
        END IF;
    END LOOP;

    RETURN CASE
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_composicion_vino
ON composicion_vino;

CREATE CONSTRAINT TRIGGER trg_validar_composicion_vino
AFTER INSERT OR UPDATE OR DELETE ON composicion_vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_trg_validar_composicion_vino();