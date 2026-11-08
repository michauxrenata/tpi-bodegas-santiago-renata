-- ============================================================
-- Archivo: 007_roles.sql
-- Etapa 2: Creación de Roles y Asignación de Privilegios Mínimos
-- ============================================================

-- Ejecutar después de:
-- 001_esquema.sql
-- 003_funciones.sql
-- 004_procedimientos.sql
-- 005_triggers.sql
-- 006_vistas.sql


-- ============================================================
-- 1. CREACIÓN DE ROLES SIN CONTRASEÑAS
-- ============================================================

-- Los roles representan conjuntos de permisos.
-- Los usuarios de conexión se crean por separado.

-- Se crea un rol técnico independiente, sin permiso de inicio de sesión, que será propietario de los procedimientos almacenados.
-- Esto permite ejecutarlos con SECURITY DEFINER sin otorgar a los usuarios de la aplicación permisos directos para modificar las tablas de stock.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'rol_admin_sistema'
    ) THEN
        CREATE ROLE rol_admin_sistema NOLOGIN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'rol_operador_ventas'
    ) THEN
        CREATE ROLE rol_operador_ventas NOLOGIN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'rol_gerente_comercial'
    ) THEN
        CREATE ROLE rol_gerente_comercial NOLOGIN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'rol_propietario_procedimientos'
    ) THEN
        CREATE ROLE rol_propietario_procedimientos NOLOGIN;
    END IF;
    
    -- Rol técnico exclusivo para los triggers de ventas.
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles
        WHERE rolname = 'rol_propietario_ventas'
    ) THEN
        CREATE ROLE rol_propietario_ventas NOLOGIN;
    END IF;

END
$$;

-- Asegurar que los roles existentes tampoco
-- puedan iniciar sesión directamente.
ALTER ROLE rol_admin_sistema NOLOGIN;
ALTER ROLE rol_operador_ventas NOLOGIN;
ALTER ROLE rol_gerente_comercial NOLOGIN;
ALTER ROLE rol_propietario_procedimientos NOLOGIN;
ALTER ROLE rol_propietario_ventas NOLOGIN;



-- ============================================================
-- 2. SEGURIDAD GENERAL DEL ESQUEMA
-- ============================================================

-- Retirar permisos públicos.
REVOKE ALL ON SCHEMA public FROM PUBLIC;

REVOKE ALL ON ALL TABLES IN SCHEMA public
FROM PUBLIC;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public
FROM PUBLIC;

REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public
FROM PUBLIC;

-- Retirar privilegios anteriores del operador
-- y gerente para reasignar únicamente los necesarios.
REVOKE ALL ON ALL TABLES IN SCHEMA public
FROM rol_operador_ventas, rol_gerente_comercial;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public
FROM rol_operador_ventas, rol_gerente_comercial;

REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public
FROM rol_operador_ventas, rol_gerente_comercial;

-- Acceso controlado al esquema.
GRANT USAGE ON SCHEMA public
TO rol_admin_sistema,
   rol_operador_ventas,
   rol_gerente_comercial;



-- Se permite al propietario técnico acceder al esquema public para ejecutar los procedimientos que procesan ingresos y transferencias,
-- manteniendo separados sus permisos de los usuarios de la aplicación.
GRANT USAGE ON SCHEMA public
TO rol_propietario_procedimientos;


-- Se otorgan al propietario técnico los permisos necesarios para consultar los documentos, validar sus renglones y actualizar
-- las existencias cuando se procesan ingresos y transferencias. Los operadores ejecutan los procedimientos sin recibir
-- permisos directos para modificar el inventario.

GRANT SELECT ON
    public.ingreso,
    public.renglon_ingreso,
    public.transferencia,
    public.renglon_transferencia,
    public.vino
TO rol_propietario_procedimientos;

GRANT UPDATE (estado) ON
    public.ingreso,
    public.transferencia
TO rol_propietario_procedimientos;

GRANT SELECT, INSERT, UPDATE ON
    public.stock_deposito,
    public.stock_sala
TO rol_propietario_procedimientos;


-- Permisos requeridos por los procedimientos de Santiago.
-- Permiten realizar LOCK TABLE ... IN SHARE MODE.
-- No se conceden al operador de la API.

GRANT UPDATE ON
    public.renglon_ingreso,
    public.renglon_transferencia
TO rol_propietario_procedimientos;



-- Se asigna la propiedad de los procedimientos a un rol técnico sin acceso de inicio de sesión, para que SECURITY DEFINER
-- permita procesar los movimientos de stock con los permisos necesarios, sin otorgarlos directamente a los operadores.

ALTER PROCEDURE public.sp_procesar_ingreso(INTEGER)
OWNER TO rol_propietario_procedimientos;

ALTER PROCEDURE public.sp_procesar_transferencia(INTEGER)
OWNER TO rol_propietario_procedimientos;

-- Para que estos ALTER PROCEDURE funcionen, la migración deberá ejecutarse con una cuenta que tenga autoridad para transferir la propiedad,
-- como el administrador de PostgreSQL utilizado en el entorno de desarrollo. Además, 004_procedimientos.sql debe haberse ejecutado previamente.


-- Propiedad de los procedimientos de cierre de Santiago.
-- Permite ejecutar el cierre mediante SECURITY DEFINER sin otorgar al operador UPDATE directo sobre el estado.

ALTER PROCEDURE public.sp_terminar_ingreso(INTEGER)
OWNER TO rol_propietario_procedimientos;

ALTER PROCEDURE public.sp_terminar_transferencia(INTEGER)
OWNER TO rol_propietario_procedimientos;


-- ============================================================
-- ROL TÉCNICO PARA LOS TRIGGERS DE VENTAS
-- ============================================================

-- Permite acceder a los objetos del esquema.
GRANT USAGE ON SCHEMA public
TO rol_propietario_ventas;

-- Permite consultar la información necesaria para validar y registrar una venta.
GRANT SELECT ON
    public.vino,
    public.cliente,
    public.comprobante,
    public.renglon_comprobante,
    public.stock_sala
TO rol_propietario_ventas;

-- Permite descontar el stock de la sala.
GRANT UPDATE (cantidad) ON public.stock_sala
TO rol_propietario_ventas;

-- Permite actualizar los importes del comprobante.
GRANT UPDATE (
    subtotal,
    descuento,
    total
) ON public.comprobante
TO rol_propietario_ventas;

-- Permite consultar la tasa de descuento vigente.
GRANT EXECUTE ON FUNCTION
    public.fn_descuento_cliente(INTEGER)
TO rol_propietario_ventas;

-- ============================================================
-- 3. ROL ADMINISTRADOR DEL SISTEMA
-- ============================================================

-- Administración de objetos existentes.
-- La propiedad real se configura por separado.

GRANT CREATE ON SCHEMA public
TO rol_admin_sistema;

-- Esto da permiso a las tablas, pero no lo convierte en su propietario
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
TO rol_admin_sistema;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
TO rol_admin_sistema;

GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public
TO rol_admin_sistema;
-- ============================================================
-- PROPIEDAD DE LOS OBJETOS Y SECURITY DEFINER
-- ============================================================

-- El rol rol_admin_sistema es NOLOGIN.
-- La asignación de propiedad de tablas y procedimientos se coordinará con Santiago y Sol.

-- Los procedimientos SECURITY DEFINER se ejecutarán con los privilegios de su propietario.

-- La API utilizará rol_operador_ventas y no recibirá permisos directos de escritura sobre las tablas de stock.





-- ============================================================
-- 4. ROL OPERADOR DE VENTAS / API
-- ============================================================

-- Consultar información necesaria para las operaciones.
GRANT SELECT ON
    vino,
    composicion_vino,
    cepa,
    maridaje,
    vino_maridaje,
    bodega,
    sala_venta,
    localidad,
    cliente,
    cliente_socio,
    cliente_distribuidor,
    cliente_exportador,
    permiso_exportacion,
    transportista,
    stock_deposito,
    stock_sala,
    comprobante,
    renglon_comprobante,
    ingreso,
    renglon_ingreso,
    transferencia,
    renglon_transferencia
TO rol_operador_ventas;

-- RN-06: el operador puede consultar cliente.descuento, pero no modificarlo directamente.
-- El descuento inicial será asignado por los triggers coordinados con Sol.
-- El descuento especial del 35 % se aplicará mediante la operación U6 de Santiago.





-- ============================================================
-- REGISTRO DE VENTAS - PERMISOS DEL OPERADOR
-- RN-08 / RN-09
-- ============================================================

-- Retirar el permiso general de inserción.
REVOKE INSERT ON
    public.comprobante,
    public.renglon_comprobante
FROM rol_operador_ventas;

-- El operador puede crear la cabecera de una venta,
-- pero no cargar manualmente subtotal, descuento ni total.
GRANT INSERT (
    fecha,
    id_cliente,
    id_sala
) ON public.comprobante
TO rol_operador_ventas;

-- Permiso temporal sobre renglones.
-- Se restringirá a columnas específicas cuando Sol
-- termine el trigger que calcula precio e importes.
GRANT INSERT ON public.renglon_comprobante
TO rol_operador_ventas;


-- Se retiran permisos generales de actualización.
REVOKE UPDATE ON
    public.comprobante,
    public.renglon_comprobante
FROM rol_operador_ventas;

-- No se concede modificación directa de stock.
-- El descuento del stock y el cálculo de importes
-- estarán protegidos por los triggers de Sol.

-- Registrar ingresos y transferencias.

-- Se revocan los permisos generales de actualización sobre los
-- documentos para impedir que el operador cambie sus estados
-- directamente, reservando el procesamiento a los procedimientos.
REVOKE UPDATE ON
    public.ingreso,
    public.renglon_ingreso,
    public.transferencia,
    public.renglon_transferencia
FROM rol_operador_ventas;


-- Se revoca cualquier permiso previo para modificar directamente
-- el estado de ingresos y transferencias, de modo que su
-- procesamiento quede controlado por los procedimientos.
REVOKE UPDATE (estado) ON public.ingreso
FROM rol_operador_ventas;

REVOKE UPDATE (estado) ON public.transferencia
FROM rol_operador_ventas;



-- ============================================================
-- PERMISOS DE INSERCIÓN DE INGRESOS Y TRANSFERENCIAS
-- RN-10 / RN-11
-- ============================================================

-- Eliminar permisos generales de inserción.
REVOKE INSERT ON
    public.ingreso,
    public.transferencia
FROM rol_operador_ventas;

-- El operador puede registrar ingresos,
-- pero no establecer directamente su estado.
GRANT INSERT (
    fecha,
    codigo_transportista,
    cuit_bodega
) ON public.ingreso
TO rol_operador_ventas;

-- El operador puede crear transferencias,
-- pero no modificar la fecha ni establecer el estado.
GRANT INSERT (id_sala)
ON public.transferencia
TO rol_operador_ventas;

-- Los renglones se pueden insertar mientras
-- el documento esté en confección.
GRANT INSERT ON
    public.renglon_ingreso,
    public.renglon_transferencia
TO rol_operador_ventas;


GRANT UPDATE (
    fecha,
    codigo_transportista,
    cuit_bodega
) ON public.ingreso
TO rol_operador_ventas;

-- RN-11: no permitir modificar la fecha de confección.
GRANT UPDATE (id_sala)
ON public.transferencia
TO rol_operador_ventas;

GRANT UPDATE (
    cod_vino,
    cantidad
) ON public.renglon_ingreso
TO rol_operador_ventas;

GRANT UPDATE (
    cod_vino,
    cantidad
) ON public.renglon_transferencia
TO rol_operador_ventas;


-- Las escrituras en stock NO se conceden directamente.
-- Requieren procedimientos seguros coordinados con Santiago y triggers de Sol.

-- ______________________________________________________________________________________

-- Permitir eliminar renglones de documentos.
-- RN-12: los triggers deben impedir eliminaciones cuando el documento ya no esté en confección.

GRANT DELETE ON
    renglon_ingreso,
    renglon_transferencia
TO rol_operador_ventas;


-- Uso de secuencias para insertar nuevos registros.
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public
TO rol_operador_ventas;


-- ============================================================
-- 5. EJECUCIÓN DE FUNCIONES DE SANTIAGO
-- ============================================================

GRANT EXECUTE ON FUNCTION
    fn_descuento_cliente(INTEGER)
TO rol_operador_ventas;

GRANT EXECUTE ON FUNCTION
    fn_calcular_descuento_cliente(INTEGER, NUMERIC)
TO rol_operador_ventas;

GRANT EXECUTE ON FUNCTION
    fn_stock_sala(INTEGER, INTEGER)
TO rol_operador_ventas;

GRANT EXECUTE ON FUNCTION
    fn_total_comprobante(INTEGER)
TO rol_operador_ventas;

GRANT EXECUTE ON FUNCTION
    fn_antiguedad_anios(DATE)
TO rol_operador_ventas;

GRANT EXECUTE ON FUNCTION
    fn_antiguedad_anios(DATE, DATE)
TO rol_operador_ventas;


-- ============================================================
-- 6. EJECUCIÓN DE PROCEDIMIENTOS TRANSACCIONALES
-- ============================================================

GRANT EXECUTE ON PROCEDURE
    sp_procesar_ingreso(INTEGER)
TO rol_operador_ventas;

GRANT EXECUTE ON PROCEDURE
    sp_procesar_transferencia(INTEGER)
TO rol_operador_ventas;

-- Permitir al operador cerrar ingresos y transferencias
-- utilizando los procedimientos controlados.

GRANT EXECUTE ON PROCEDURE
    public.sp_terminar_ingreso(INTEGER),
    public.sp_terminar_transferencia(INTEGER)
TO rol_operador_ventas;

-- ============================================================
-- 7. ACCESO A LAS VISTAS DEL SISTEMA
-- ============================================================

-- El operador consulta las vistas desde la API.
GRANT SELECT ON
    vw_stock_total_vinos,
    vw_clientes_exportadores_info,
    vw_resumen_comprobantes
TO rol_operador_ventas;


-- ============================================================
-- 8. ROL GERENTE COMERCIAL - SOLO LECTURA
-- ============================================================

-- Acceso a reportes mediante vistas.
GRANT SELECT ON
    vw_stock_total_vinos,
    vw_clientes_exportadores_info,
    vw_resumen_comprobantes
TO rol_gerente_comercial;


-- ============================================================
-- FIN DEL ARCHIVO 007_roles.sql
-- ============================================================
