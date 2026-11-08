-- RN-06/U6: fuente única = cliente.descuento vigente. Requiere 002 de Valentina.
-- Santiago · H2. Tasas en [0,1]; importes monetarios con dos decimales.
-- STABLE: consulta tablas y usa la instantánea de la sentencia.
CREATE OR REPLACE FUNCTION public.fn_descuento_cliente(p_id_cliente INTEGER)
RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE v_tasa NUMERIC;
BEGIN
    SELECT c.descuento INTO v_tasa
    FROM public.cliente c WHERE c.id_cliente = p_id_cliente;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente % inexistente', p_id_cliente USING ERRCODE = 'P0002';
    END IF;
    IF v_tasa IS NULL OR v_tasa < 0 OR v_tasa > 1 OR v_tasa::text = 'NaN' THEN
        RAISE EXCEPTION 'Descuento vigente inválido para cliente %', p_id_cliente USING ERRCODE = '23514';
    END IF;
    RETURN v_tasa;
END;
$$;

-- Conserva la firma y el significado anterior: devuelve importe NETO, no descuento.
CREATE OR REPLACE FUNCTION public.fn_calcular_descuento_cliente(p_id_cliente INTEGER, p_monto NUMERIC)
RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
BEGIN
    IF p_monto IS NULL OR p_monto < 0 OR p_monto::text IN ('NaN','Infinity','-Infinity') THEN
        RAISE EXCEPTION 'Monto inválido' USING ERRCODE = '22023';
    END IF;
    RETURN ROUND(p_monto, 2) - ROUND(ROUND(p_monto, 2) * public.fn_descuento_cliente(p_id_cliente), 2);
END;
$$;

-- Stock ausente equivale a cero; no reemplaza el bloqueo al efectuar una venta.
CREATE OR REPLACE FUNCTION public.fn_stock_sala(p_sala INTEGER, p_vino INTEGER)
RETURNS INTEGER LANGUAGE sql STABLE AS $$
    SELECT COALESCE((SELECT cantidad FROM public.stock_sala
        WHERE id_sala = p_sala AND cod_vino = p_vino), 0);
$$;

-- Total histórico: suma importes netos guardados, sin aplicar la tasa actual.
-- Contrato: renglon.descuento = importe monetario; renglon.subtotal = NETO.
CREATE OR REPLACE FUNCTION public.fn_total_comprobante(p_numero INTEGER)
RETURNS NUMERIC LANGUAGE plpgsql STABLE AS $$
DECLARE v_total NUMERIC;
BEGIN
    IF NOT EXISTS (SELECT FROM public.comprobante WHERE numero_comprobante = p_numero) THEN
        RAISE EXCEPTION 'Comprobante % inexistente', p_numero USING ERRCODE = 'P0002';
    END IF;
    SELECT COALESCE(SUM(subtotal), 0) INTO v_total
    FROM public.renglon_comprobante WHERE numero_comprobante = p_numero;
    RETURN v_total;
END;
$$;

-- Años completos; la variante con fecha explícita permite pruebas reproducibles.
CREATE OR REPLACE FUNCTION public.fn_antiguedad_anios(p_fecha DATE, p_referencia DATE)
RETURNS INTEGER LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT EXTRACT(YEAR FROM AGE(p_referencia, p_fecha))::INTEGER;
$$;
CREATE OR REPLACE FUNCTION public.fn_antiguedad_anios(p_fecha DATE)
RETURNS INTEGER LANGUAGE sql STABLE STRICT AS $$
    SELECT public.fn_antiguedad_anios(p_fecha, CURRENT_DATE);
$$;
