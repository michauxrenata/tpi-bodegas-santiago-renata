-- Santiago · H4. Candidatos: validar contra la carga H3, no prometer uso del planner.
-- 1. Compuesto: igualdad de sala antes del rango de fecha (S8 por sala).
CREATE INDEX idx_comprobante_sala_fecha ON comprobante (id_sala, fecha);
-- 2. Parcial: solamente pendientes para S5; predicado idéntico al de la consulta.
CREATE INDEX idx_transferencia_pendientes ON transferencia (id_sala, fecha_confeccion)
WHERE estado <> 'procesado';
-- 3. FK inversa: PK actual empieza por comprobante, no por vino (S1/U5).
CREATE INDEX idx_renglon_comprobante_vino ON renglon_comprobante (cod_vino);
-- 4. Variante INCLUDE: filtro por fecha para S8 global; sala/total disponibles en índice.
-- Un Index Only Scan también depende del visibility map (VACUUM).
CREATE INDEX idx_comprobante_fecha_incl ON comprobante (fecha) INCLUDE (id_sala, total);
-- 5. Compuesto: rango de fechas primero para S4 global en todas las salas.
CREATE INDEX idx_transferencia_fecha_sala ON transferencia (fecha_confeccion, id_sala);
