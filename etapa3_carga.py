
import random
from decimal import Decimal
from datetime import datetime, date, timedelta
from faker import Faker
import psycopg2
from psycopg2.extras import execute_values
import os

# 1. Configuración de reproducibilidad (Semilla y fecha fija según H3)
SEED = 42
fake = Faker('es_AR')
Faker.seed(SEED)
random.seed(SEED)

FECHA_REFERENCIA_FIJA = date(2025, 1, 15)

# 2. Configuración de conexión a PostgreSQL
# Las credenciales se obtienen de variables de entorno.

DB_CONFIG = {
    "dbname": os.getenv("DB_NAME", "bodegas_del_atuel"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "client_encoding": "UTF8"
}

# Porque las credenciales de PostgreSQL no deben quedar guardadas directamente en archivos que después se suben a GitHub.


def generar_carga_nivel_0(cur):
    """Inserta los datos del Nivel 0 adaptados a las tablas de Santiago"""
    print("--- Cargando Nivel 0 ---")
    
    # 1. Localidades (codigo_postal PK, nombre, provincia, encargado_regional)
    
    # 1. LOCALIDADES
    # Catálogo inicial de localidades reales de Mendoza.
    # Los códigos postales se utilizan como identificadores.

    localidades = [
        ("5620", "General Alvear", "Mendoza", "Encargado General Alvear"),
        ("5600", "San Rafael", "Mendoza", "Encargado San Rafael"),
        ("5500", "Mendoza", "Mendoza", "Encargado Mendoza"),
        ("5519", "Guaymallén", "Mendoza", "Encargado Guaymallén"),
        ("5501", "Godoy Cruz", "Mendoza", "Encargado Godoy Cruz"),
        ("5507", "Luján de Cuyo", "Mendoza", "Encargado Luján de Cuyo")
    ]

    execute_values(
        cur,
        """
        INSERT INTO localidad
        (codigo_postal, nombre, provincia, encargado_regional)
        VALUES %s
        ON CONFLICT (codigo_postal) DO NOTHING
        """,
        localidades
    )

    print("✓ Localidades cargadas")

    
    # 2. Cepas (nombre, tipo) -> tipo_cepa es un enum o varchar según su esquema
    cepas = [
        ("Malbec", "tinta"),
        ("Cabernet Sauvignon", "tinta"),
        ("Bonarda", "tinta"),
        ("Syrah", "tinta"),
        ("Merlot", "tinta"),
        ("Tempranillo", "tinta"),
        ("Pinot Noir", "tinta"),
        ("Cabernet Franc", "tinta"),
        ("Chardonnay", "blanca"),
        ("Torrontés", "blanca"),
        ("Sauvignon Blanc", "blanca"),
        ("Chenin Blanc", "blanca")
    ]
    execute_values(
        cur,
        """
        INSERT INTO cepa (nombre, tipo)
        VALUES %s
        ON CONFLICT (nombre) DO NOTHING
        """,
        cepas
    )

    print("✓ Cepas cargadas")

    """Cada variedad queda asociada con su tipo correcto, se respeta el ENUM tipo_cepa de PostgreSQL, no se generan clasificaciones
    aleatorias incorrectas y se evita duplicar nombres de cepas."""
    #Coordinar con RENATA los CVS definitivos.
    
    # 3. Bodegas
    # Datos sintéticos con CUIT de 11 dígitos.
    # El esquema valida el formato, no el dígito verificador.

    bodegas = []
    cuits_generados = set()

    while len(bodegas) < 10:
        prefijo = random.choice(["20", "23", "27", "30"])
        numero = random.randint(100000000, 999999999)
        cuit = f"{prefijo}{numero}"

        if cuit not in cuits_generados:
            cuits_generados.add(cuit)

            bodegas.append((
                cuit,
                fake.company()[:150],
                fake.street_address()[:200]
            ))

    execute_values(
        cur,
        """
        INSERT INTO bodega (cuit, razon_social, domicilio)
        VALUES %s
        ON CONFLICT (cuit) DO NOTHING
        """,
        bodegas
    )

    print("✓ Bodegas cargadas")

    """Acá se generan 10 bodegas ficticias para las pruebas, se evita repetir CUIT dentro del lote generado, se respetan las columnas cuit, 
    razon_social y domicilio, se mantienen la reproducibilidad mediante la semilla 42 y evita duplicados de CUIT si ejecutás nuevamente 
    esta inserción."""
    
    # 4. Transportistas
    # Datos sintéticos respetando las restricciones de unicidad de CUIT y correo electrónico.

    transportistas = []
    cuits_transportistas = set()
    emails_transportistas = set()

    while len(transportistas) < 15:
        prefijo = random.choice(["20", "23", "27", "30"])
        numero = random.randint(100000000, 999999999)
        cuit = f"{prefijo}{numero}"

        email = fake.unique.email()

        if (
            cuit not in cuits_transportistas
            and cuit not in cuits_generados
            and email not in emails_transportistas
        ):
            cuits_transportistas.add(cuit)
            emails_transportistas.add(email)

            transportistas.append((
                fake.company()[:150],
                cuit,
                email,
                fake.phone_number()[:30],
                fake.street_address()[:200]
            ))

    execute_values(
        cur,
        """
        INSERT INTO transportista
        (razon_social, cuit, email, telefono, domicilio)
        VALUES %s
        ON CONFLICT DO NOTHING
        """,
        transportistas
    )

    print("✓ Transportistas cargados")

    """
    Evitamos:
      -repetir CUIT dentro de los transportistas generados.
      -repetir correos electrónicos, como exige tu 002_constraints.sql.
      -que los CUIT sintéticos coincidan con los generados para las bodegas.
    Respetamos las columnas y los tipos de 001_esquema.sql.
    Mantenemos el uso de Faker y la semilla fija para generar datos reproducibles.
    """



    # 5. FINCAS
    # Columnas: id_finca (IDENTITY), nombre,
    # superficie_ha, departamento y provincia.
    # Generamos datos sintéticos con superficies positivas.


    departamentos = [
        "General Alvear",
        "San Rafael",
        "San Carlos",
        "Tunuyán",
        "Tupungato",
        "Maipú",
        "Luján de Cuyo",
        "Rivadavia",
        "Junín",
        "San Martín"
    ]

    fincas = []

    for i in range(1, 51):
        nombre = f"Finca {i:03d}"
        superficie = round(random.uniform(20.0, 250.0), 2)
        departamento = random.choice(departamentos)

        fincas.append((
            nombre,
            superficie,
            departamento,
            "Mendoza"
        ))

    execute_values(
        cur,
        """
        INSERT INTO finca
        (nombre, superficie_ha, departamento, provincia)
        VALUES %s
        ON CONFLICT DO NOTHING
        """,
        fincas
    )

    print("✓ Fincas cargadas")

    """
    Acá lo que hacemos es:
    Generar 50 fincas con nombres diferentes.
    Todas las superficies son positivas, cumpliendo la RN-15.
    Utilizar departamentos reales de Mendoza.
    Mantener la semilla 42 para obtener valores reproducibles.
    Un detalle importante es que finca tiene una clave primaria autogenerada, por lo que ON CONFLICT DO NOTHING no impide 
    volver a insertar las mismas fincas si ejecutás nuevamente el script. 
    """

    # 6. MARIDAJES
    # Catálogo de maridajes y temperaturas sugeridas.
    # Las temperaturas se expresan en grados Celsius.

    maridajes = [
        ("Carnes rojas", 17.0),
        ("Carnes blancas", 12.0),
        ("Pescados", 10.0),
        ("Mariscos", 9.0),
        ("Quesos duros", 16.0),
        ("Quesos blandos", 12.0),
        ("Pastas", 15.0),
        ("Pizzas", 15.0),
        ("Ensaladas", 10.0),
        ("Postres", 8.0),
        ("Chocolate", 16.0),
        ("Frutos secos", 14.0)
    ]

    execute_values(
        cur,
        """
        INSERT INTO maridaje
        (nombre, temp_servicio_sugerida_c)
        VALUES %s
        ON CONFLICT (nombre) DO NOTHING
        """,
        maridajes
    )

    print("✓ Maridajes cargados")
    """
    Lo hacemos asi porque usamos categorías de maridaje reconocibles en lugar de nombres aleatorios, también cada maridaje tiene 
    una temperatura sugerida. Respetamos las columnas de 001_esquema.sql, evitamos duplicar nombres mediante ON CONFLICT (nombre) 
    DO NOTHING y los datos podrán utilizarse después en la tabla vino_maridaje.
    """

    #tenemos que incorporar los descuentos que acordaron con Santiago y preparar los datos para las ventas masivas.

    
    # 7. CLIENTES: Generación de 20.000 clientes sintéticos.
    # RN-06: descuento según tipo de cliente.
    # Semilla fija para reproducibilidad.

    tipos_cliente = ["socio", "distribuidor", "exportador"]

    descuentos = {
        "socio": 0.10,
        "distribuidor": 0.20,
        "exportador": 0.30
    }

    clientes = []

    for i in range(1, 20001):
        tipo = random.choice(tipos_cliente)

        clientes.append((
            fake.name()[:150],
            "DNI",
            f"{30000000 + i}",
            fake.street_address()[:200],
            random.choice([
                "General Alvear",
                "San Rafael",
                "Mendoza",
                "Godoy Cruz",
                "Tunuyán"
            ]),
            FECHA_REFERENCIA_FIJA,
            tipo,
            descuentos[tipo]
        ))

    execute_values(
        cur,
        """
        INSERT INTO cliente
        (
            nombre_razon_social,
            tipo_doc,
            nro_doc,
            direccion,
            localidad,
            fecha_alta,
            tipo_cliente,
            descuento
        )
        VALUES %s
        ON CONFLICT (nro_doc) DO NOTHING
        """,
        clientes,
        page_size=1000
    )

    print("✓ Clientes cargados")
"""
* Generamos 20.000 clientes sintéticos, como recomienda el profesor.
* Asignamos un tipo a cada cliente.
* Asociamos el descuento correspondiente: 10 %, 20 % o 30 %.
* Utilizamos una fecha fija para mantener la reproducibilidad.
* Insertamos en lotes de 1.000 registros, en lugar de hacerlo uno por uno.
* Evitamos repetir números de documento gracias a ON CONFLICT (nro_doc) DO NOTHING.

Hay dos detalles del Nivel 0 que debemos tener presentes
Primero: el código inserta explícitamente cliente.descuento. Eso es coherente con el acuerdo de Santiago, 
pero la columna todavía depende de la migración que tenemos guardada en la rama de la Etapa 2 y del trigger de Sol.

Segundo: si ejecuto el programa varias veces sobre la misma base, podrías duplicar fincas, porque ON CONFLICT DO NOTHING 
no evita duplicados de datos cuando no existe una restricción de unicidad aplicable. Para la carga definitiva vamos a utilizar 
una estrategia reproducible sobre una base de prueba preparada.
"""



def generar_carga_nivel_1(cur):
    """Inserta los datos del Nivel 1 respetando claves foráneas y restricciones de negocio"""
    print("--- Cargando Nivel 1 ---")
    
    # Obtenemos claves foráneas existentes del Nivel 0 para mantener la integridad referencial
    cur.execute("SELECT codigo_postal FROM localidad;")
    codigos_postales = [row[0] for row in cur.fetchall()]
    
    cur.execute("SELECT id_finca FROM finca;")
    ids_fincas = [row[0] for row in cur.fetchall()]
    
    cur.execute("SELECT id_cepa FROM cepa;")
    ids_cepas = [row[0] for row in cur.fetchall()]
    
    cur.execute("SELECT cuit FROM bodega;")
    cuits_bodegas = [row[0] for row in cur.fetchall()]
    
    cur.execute("SELECT codigo_transportista FROM transportista;")
    codigos_transportistas = [row[0] for row in cur.fetchall()]

    cur.execute("SELECT id_cliente FROM cliente;")
    ids_clientes = [row[0] for row in cur.fetchall()]

    
    if (
        not codigos_postales
        or not cuits_bodegas
        or not ids_fincas
        or not ids_cepas
        or not codigos_transportistas
        or not ids_clientes
    ):
        raise ValueError(
            "Nivel 1: faltan registros del Nivel 0. "
            "No se puede continuar con la carga."
        )

        """
        raise ValueError interrumpe la ejecución y permite revertir la transacción si faltan datos esenciales. 
        Así evitamos guardar una carga parcial como si hubiera terminado correctamente.
        """


    # 1. SALAS DE VENTA
    # Cada sala pertenece a una localidad existente (RN-02).

    dias = [
        "Lunes", "Martes", "Miércoles",
        "Jueves", "Viernes", "Sábado", "Domingo"
    ]

    salas = []
    direcciones_generadas = set()

    while len(salas) < 15:
        calle = fake.street_name()[:100]
        numero = str(random.randint(1, 4000))
        codigo_postal = random.choice(codigos_postales)

        direccion = (calle, numero, codigo_postal)

        if direccion not in direcciones_generadas:
            direcciones_generadas.add(direccion)

            salas.append((
                calle,
                numero,
                random.choice(dias),
                codigo_postal
            ))

    execute_values(
        cur,
        """
        INSERT INTO sala_venta
        (calle, numero, dia_cierre, codigo_postal)
        VALUES %s
        """,
        salas
    )

    print("✓ Salas de venta cargadas")

    """
    - Respeta la clave foránea entre sala_venta y localidad.
    - Genera 15 salas de venta.
    - Incluye todos los días posibles de cierre.
    - Evita repetir direcciones dentro del lote generado.
    - Mantiene la reproducibilidad mediante la semilla fija.
    Importante: el esquema actual no tiene un UNIQUE para la dirección de las salas. 
    Por eso, la prevención de duplicados ocurre en Python, no en PostgreSQL. La prueba final la haremos 
    sobre una base de pruebas preparada desde cero.
    """


    
    # 2. PARCELAS
    # Cada parcela pertenece a una finca (RN-04). La suma de superficies de las 
    # parcelas no debe superar la superficie total de su finca.

    cur.execute("""
        SELECT id_finca, superficie_ha
        FROM finca
        ORDER BY id_finca
    """)
    fincas_disponibles = cur.fetchall()

    parcelas = []

    for id_finca, superficie_finca in fincas_disponibles:

        # Cada finca tendrá entre 2 y 4 parcelas.
        cantidad_parcelas = random.randint(2, 4)

        # Utilizamos el 80 % de la superficie total.
        
        superficie_disponible = int(
            superficie_finca * Decimal("80")
        )


        # Distribuimos las hectáreas en partes positivas.
        cortes = sorted(random.sample(
            range(1, superficie_disponible),
            cantidad_parcelas - 1
        ))

        superficies = [
            b - a
            for a, b in zip(
                [0] + cortes,
                cortes + [superficie_disponible]
            )
        ]

        for nro, superficie_centésimas in enumerate(
            superficies, start=1
        ):
            parcelas.append((
                id_finca,
                nro,
                superficie_centésimas / 100,
                random.randint(1990, 2022),
                random.choice(ids_cepas)
            ))

    execute_values(
        cur,
        """
        INSERT INTO parcela
        (
            id_finca,
            nro_parcela,
            superficie_ha,
            anio_plantacion,
            id_cepa
        )
        VALUES %s
        ON CONFLICT (id_finca, nro_parcela) DO NOTHING
        """,
        parcelas
    )

    print(f"✓ Parcelas cargadas: {len(parcelas)} generadas")

    """
    Cada parcela está asociada a una finca existente.
    Cada finca tiene entre 2 y 4 parcelas.
    Las parcelas ocupan en conjunto el 80 % de la superficie de su finca.
    Ninguna parcela tiene superficie cero o negativa.
    Cada parcela tiene una cepa válida y un año de plantación.
    Se respeta la clave primaria compuesta (id_finca, nro_parcela).
    """

    
    # 3. VINOS
    # Generación de vinos sintéticos.
    # Se respetan los tipos ENUM y las restricciones de precio, volumen y graduación alcohólica.

    tipos_vino = [
        "tinto",
        "blanco",
        "rosado",
        "espumante"
    ]

    nombres_vino = [
        "Malbec Reserva",
        "Cabernet Sauvignon Reserva",
        "Bonarda Clásico",
        "Syrah Roble",
        "Merlot Reserva",
        "Chardonnay Selección",
        "Torrontés Clásico",
        "Pinot Noir Reserva",
        "Cabernet Franc Roble",
        "Blend del Atuel"
    ]

    vinos = []
    combinaciones_generadas = set()

    while len(vinos) < 300:
        nombre = random.choice(nombres_vino)
        tipo = random.choice(tipos_vino)
        anada = random.randint(2018, 2024)
        volumen = random.choice([375, 750, 1500])
        graduacion = round(random.uniform(11.5, 14.5), 2)
        precio = round(random.uniform(3500, 45000), 2)
        cuit_bodega = random.choice(cuits_bodegas)

        clave = (cuit_bodega, nombre, anada, volumen)

        if clave in combinaciones_generadas:
            continue

        combinaciones_generadas.add(clave)

        vinos.append((
            nombre,
            tipo,
            anada,
            volumen,
            graduacion,
            precio,
            cuit_bodega
        ))

    execute_values(
        cur,
        """
        INSERT INTO vino
        (
            nombre,
            tipo,
            anada,
            volumen_ml,
            graduacion,
            precio,
            cuit_bodega
        )
        VALUES %s
        ON CONFLICT DO NOTHING
        """,
        vinos,
        page_size=500
    )

    print(f"✓ Vinos generados: {len(vinos)}")

    """
    Este bloque se encarga de:
    - Generar 300 vinos sintéticos.
    - Asignar sus características y precios.
    - Relacionar cada vino con una bodega existente.
    - Evitar combinaciones duplicadas.
    - Respetar las restricciones de la base de datos.
    - Insertar los registros por lotes.
    """


    
    # 4. SUBTIPOS DE CLIENTES
   

    # Obtener los clientes según su tipo registrado.
    cur.execute("""
        SELECT id_cliente, tipo_cliente
        FROM cliente
        ORDER BY id_cliente
    """)

    clientes_registrados = cur.fetchall()

    socios = []
    distribuidores = []
    exportadores = []

    for id_cliente, tipo in clientes_registrados:

        if tipo == "socio":
            socios.append((id_cliente,))

        elif tipo == "distribuidor":
            distribuidores.append((
                id_cliente,
                random.choice([
                    "General Alvear",
                    "San Rafael",
                    "Gran Mendoza",
                    "Valle de Uco",
                    "Zona Este"
                ]),
                f"HAB-{id_cliente:08d}"
            ))

        elif tipo == "exportador":
            exportadores.append((
                id_cliente,
                random.choice([
                    "Brasil",
                    "Chile",
                    "Estados Unidos",
                    "España",
                    "Francia",
                    "Alemania",
                    "México"
                ])
            ))

        else:
            raise ValueError(
                f"Tipo de cliente desconocido: {tipo}"
            )

    # Registrar socios.
    if socios:
        execute_values(
            cur,
            """
            INSERT INTO cliente_socio (id_cliente)
            VALUES %s
            ON CONFLICT (id_cliente) DO NOTHING
            """,
            socios,
            page_size=1000
        )

    # Registrar distribuidores.
    if distribuidores:
        execute_values(
            cur,
            """
            INSERT INTO cliente_distribuidor
            (id_cliente, zona_cobertura, nro_habilitacion)
            VALUES %s
            ON CONFLICT (id_cliente) DO NOTHING
            """,
            distribuidores,
            page_size=1000
        )

    # Registrar exportadores.
    if exportadores:
        execute_values(
            cur,
            """
            INSERT INTO cliente_exportador
            (id_cliente, pais_destino_principal)
            VALUES %s
            ON CONFLICT (id_cliente) DO NOTHING
            """,
            exportadores,
            page_size=1000
        )

    print(f"✓ Socios: {len(socios)}")
    print(f"✓ Distribuidores: {len(distribuidores)}")
    print(f"✓ Exportadores: {len(exportadores)}")
    print("✓ Subtipos de clientes cargados")

    """
    Este bloque se encarga de:
    - Clasificar los clientes según su tipo.
    - Registrar cada cliente en su tabla correspondiente.
    - Generar los datos adicionales de distribuidores y exportadores.
    - Evitar registros duplicados.
    - Respetar las claves foráneas.
    """


    
    # 5. TRANSPORTISTA_COBERTURA

    coberturas = []

    for codigo_transportista in sorted(codigos_transportistas):

        localidades_asignadas = random.sample(
            sorted(codigos_postales),
            k=min(3, len(codigos_postales))
        )

        for codigo_postal in localidades_asignadas:
            coberturas.append((
                codigo_transportista,
                codigo_postal
            ))

    if coberturas:
        execute_values(
            cur,
            """
            INSERT INTO transportista_cobertura
            (codigo_transportista, codigo_postal)
            VALUES %s
            ON CONFLICT (codigo_transportista, codigo_postal)
            DO NOTHING
            """,
            coberturas,
            page_size=1000
        )

    print(f"✓ Coberturas generadas: {len(coberturas)}")

    """
    Este bloque se encarga de:
    - Asignar 3 localidades a cada transportista.
    - Relacionar transportistas con localidades existentes.
    - Evitar coberturas duplicadas.
    - Insertar las relaciones en la base de datos.
    """


    
    # 6. INGRESO

    estados_doc = [
        "en_confeccion",
        "terminado",
        "procesado"
    ]

    ingresos = []

    for _ in range(100):

        dias_atras = random.randint(0, 365)

        fecha_ingreso = (
            FECHA_REFERENCIA_FIJA
            - timedelta(days=dias_atras)
        )

        ingresos.append((
            fecha_ingreso,
            random.choice(estados_doc),
            random.choice(codigos_transportistas),
            random.choice(cuits_bodegas)
        ))

    execute_values(
        cur,
        """
        INSERT INTO ingreso
        (
            fecha,
            estado,
            codigo_transportista,
            cuit_bodega
        )
        VALUES %s
        """,
        ingresos,
        page_size=1000
    )

    print(f"✓ Ingresos cargados: {len(ingresos)}")

    """
    Este bloque se encarga de:
    - Generar 100 ingresos de mercadería.
    - Asignar una fecha y un estado válido.
    - Relacionar cada ingreso con una bodega.
    - Asignar un transportista existente.
    - Insertar los ingresos en la base de datos.
    """


def generar_carga_nivel_2(cur):
    # NIVEL 2
    # Este nivel se encargará de:
    # *Generar empleados y lotes de uva.
    # *Registrar composiciones y maridajes de vinos.
    # *Crear permisos de exportación.
    # *Preparar los movimientos de mercadería y ventas.
    # *Respetar las relaciones y reglas de negocio.

    print("\n--- Cargando Nivel 2 ---")

    
    # 1. EMPLEADOS

    cur.execute("""
        SELECT id_sala
        FROM sala_venta
        ORDER BY id_sala
    """)

    ids_salas = [fila[0] for fila in cur.fetchall()]

    if not ids_salas:
        raise ValueError(
            "No existen salas de venta para asignar empleados."
        )

    empleados = []

    for i in range(300):
        cuit = f"27{500000000 + i:09d}"
        nombre = fake.name()[:150]

        fecha_ingreso = (
            FECHA_REFERENCIA_FIJA
            - timedelta(days=random.randint(30, 3650))
        )

        salario = round(random.uniform(500000, 2500000), 2)

        # Repartimos empleados entre las salas existentes.
        id_sala = ids_salas[i % len(ids_salas)]

        empleados.append((
            cuit,
            nombre,
            fecha_ingreso,
            salario,
            id_sala
        ))

    execute_values(
        cur,
        """
        INSERT INTO empleado
        (
            cuit,
            nombre,
            fecha_ingreso,
            salario,
            id_sala
        )
        VALUES %s
        ON CONFLICT (cuit) DO NOTHING
        """,
        empleados,
        page_size=1000
    )

    print(f"✓ Empleados generados: {len(empleados)}")

    """
    Este bloque se encarga de:
    - Generar 300 empleados sintéticos.
    - Asignarles CUIT, nombre, salario y fecha de ingreso.
    - Relacionar cada empleado con una sala existente.
    - Evitar empleados duplicados.
    - Insertar los registros por lotes.
    """
    
    # 2. LOTES DE UVA

    cur.execute("""
        SELECT id_finca, nro_parcela
        FROM parcela
        ORDER BY id_finca, nro_parcela
    """)

    parcelas_disponibles = cur.fetchall()

    cur.execute("""
        SELECT cuit
        FROM bodega
        ORDER BY cuit
    """)

    bodegas_disponibles = [
        fila[0] for fila in cur.fetchall()
    ]

    if not parcelas_disponibles or not bodegas_disponibles:
        raise ValueError(
            "Faltan parcelas o bodegas para generar lotes de uva."
        )

    lotes = []

    for id_finca, nro_parcela in parcelas_disponibles:

        # Generamos una cosecha por campaña.
        for campana in [2022, 2023, 2024]:

            fecha_cosecha = date(
                campana,
                random.randint(2, 4),
                random.randint(1, 28)
            )

            kg_cosechados = round(
                random.uniform(500, 20000),
                2
            )

            cuit_bodega_destino = random.choice(
                bodegas_disponibles
            )

            lotes.append((
                id_finca,
                nro_parcela,
                campana,
                fecha_cosecha,
                kg_cosechados,
                cuit_bodega_destino
            ))

    execute_values(
        cur,
        """
        INSERT INTO lote_uva
        (
            id_finca,
            nro_parcela,
            campana,
            fecha_cosecha,
            kg_cosechados,
            cuit_bodega_destino
        )
        VALUES %s
        ON CONFLICT DO NOTHING
        """,
        lotes,
        page_size=1000
    )

    print(f"✓ Lotes de uva generados: {len(lotes)}")

    """
    Este bloque se encarga de:
    - Generar cosechas de uva para las parcelas existentes.
    - Registrar la campaña, fecha y kilos cosechados.
    - Asignar una bodega de destino a cada lote.
    - Evitar repetir una cosecha por parcela y campaña.
    - Insertar los registros por lotes.
    """

    
    # 3. COMPOSICIÓN DE VINOS

    cur.execute("""
        SELECT cod_vino
        FROM vino
        ORDER BY cod_vino
    """)
    ids_vinos = [fila[0] for fila in cur.fetchall()]

    cur.execute("""
        SELECT id_cepa
        FROM cepa
        ORDER BY id_cepa
    """)
    ids_cepas_disponibles = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_vinos or not ids_cepas_disponibles:
        raise ValueError(
            "Faltan vinos o cepas para generar composiciones."
        )

    composiciones = []

    for cod_vino in ids_vinos:

        cantidad_cepas = random.randint(
            1,
            min(3, len(ids_cepas_disponibles))
        )

        cepas_elegidas = random.sample(
            ids_cepas_disponibles,
            cantidad_cepas
        )

        if cantidad_cepas == 1:
            porcentajes = [10000]
        else:
            cortes = sorted(
                random.sample(
                    range(1, 10000),
                    cantidad_cepas - 1
                )
            )

            porcentajes = [
                b - a
                for a, b in zip(
                    [0] + cortes,
                    cortes + [10000]
                )
            ]

        for id_cepa, porcentaje in zip(
            cepas_elegidas,
            porcentajes
        ):
            composiciones.append((
                cod_vino,
                id_cepa,
                Decimal(porcentaje) / Decimal(100)
            ))

    execute_values(
        cur,
        """
        INSERT INTO composicion_vino
        (
            cod_vino,
            id_cepa,
            porcentaje
        )
        VALUES %s
        ON CONFLICT (cod_vino, id_cepa)
        DO NOTHING
        """,
        composiciones,
        page_size=1000
    )

    print(
        f"✓ Composiciones generadas: {len(composiciones)}"
    )
    """
    Este bloque se encarga de:
    - Obtener los vinos y las cepas existentes.
    - Asignar entre 1 y 3 cepas a cada vino.
    - Distribuir sus porcentajes hasta sumar el 100 %.
    - Evitar repetir una cepa dentro del mismo vino.
    - Insertar las composiciones por lotes.
    """

    
    # 4. VINO_MARIDAJE

    cur.execute("""
        SELECT cod_vino
        FROM vino
        ORDER BY cod_vino
    """)

    ids_vinos_maridaje = [
        fila[0] for fila in cur.fetchall()
    ]

    cur.execute("""
        SELECT id_maridaje
        FROM maridaje
        ORDER BY id_maridaje
    """)

    ids_maridajes = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_vinos_maridaje or not ids_maridajes:
        raise ValueError(
            "Faltan vinos o maridajes para generar relaciones."
        )

    relaciones_maridaje = []

    for cod_vino in ids_vinos_maridaje:

        cantidad_maridajes = random.randint(
            1,
            min(3, len(ids_maridajes))
        )

        maridajes_elegidos = random.sample(
            ids_maridajes,
            cantidad_maridajes
        )

        for id_maridaje in maridajes_elegidos:
            relaciones_maridaje.append((
                cod_vino,
                id_maridaje
            ))

    execute_values(
        cur,
        """
        INSERT INTO vino_maridaje
        (
            cod_vino,
            id_maridaje
        )
        VALUES %s
        ON CONFLICT (cod_vino, id_maridaje)
        DO NOTHING
        """,
        relaciones_maridaje,
        page_size=1000
    )

    print(
        f"✓ Relaciones vino-maridaje generadas: "
        f"{len(relaciones_maridaje)}"
    )

    """
    Este bloque se encarga de:
    - Obtener los vinos y maridajes existentes.
    - Asignar entre 1 y 3 maridajes a cada vino.
    - Evitar relaciones duplicadas.
    - Respetar las claves foráneas.
    - Insertar las relaciones por lotes.
    """

    
    # 5. PERMISOS DE EXPORTACIÓN

    cur.execute("""
        SELECT id_cliente
        FROM cliente_exportador
        ORDER BY id_cliente
    """)

    ids_exportadores = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_exportadores:
        raise ValueError(
            "No existen clientes exportadores para generar permisos."
        )

    permisos = []

    for id_exportador in ids_exportadores:

        cantidad_permisos = random.randint(1, 5)

        for numero in range(1, cantidad_permisos + 1):

            fecha_emision = (
                FECHA_REFERENCIA_FIJA
                - timedelta(days=random.randint(30, 1000))
            )

            fecha_vencimiento = (
                fecha_emision
                + timedelta(days=random.randint(365, 730))
            )

            codigo_permiso = (
                f"EXP-{id_exportador:08d}-{numero:02d}"
            )

            permisos.append((
                codigo_permiso,
                id_exportador,
                fecha_emision,
                fecha_vencimiento
            ))

    execute_values(
        cur,
        """
        INSERT INTO permiso_exportacion
        (
            cod_permiso,
            id_cliente_exportador,
            fecha_emision,
            fecha_vencimiento
        )
        VALUES %s
        ON CONFLICT (cod_permiso) DO NOTHING
        """,
        permisos,
        page_size=1000
    )

    print(
        f"✓ Permisos de exportación generados: "
        f"{len(permisos)}"
    )

    """
    Este bloque se encarga de:
    - Obtener los clientes exportadores existentes.
    - Generar entre 1 y 5 permisos por exportador.
    - Asignar fechas de emisión y vencimiento válidas.
    - Evitar códigos de permiso duplicados.
    - Insertar los permisos por lotes.
    """

    
    # 6. STOCK_DEPÓSITO
    
    cur.execute("""
        SELECT cod_vino
        FROM vino
        ORDER BY cod_vino
    """)

    ids_vinos_stock = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_vinos_stock:
        raise ValueError(
            "No existen vinos para inicializar el stock."
        )

    stock_inicial = [
        (cod_vino, 0)
        for cod_vino in ids_vinos_stock
    ]

    execute_values(
        cur,
        """
        INSERT INTO stock_deposito
        (
            cod_vino,
            cantidad
        )
        VALUES %s
        ON CONFLICT (cod_vino) DO NOTHING
        """,
        stock_inicial,
        page_size=1000
    )

    print(
        f"✓ Registros de stock inicial generados: "
        f"{len(stock_inicial)}"
    )

    """
    Este bloque se encarga de:
    - Obtener todos los vinos existentes.
    - Crear un registro de stock para cada vino.
    - Inicializar las cantidades en cero.
    - Evitar registros duplicados.
    - Preparar el inventario para futuros ingresos.
    
    """

    
    # 7. RENGLONES DE INGRESO

    cur.execute("""
        SELECT codigo_ingreso
        FROM ingreso
        ORDER BY codigo_ingreso
    """)

    ids_ingresos = [
        fila[0] for fila in cur.fetchall()
    ]

    cur.execute("""
        SELECT cod_vino
        FROM vino
        ORDER BY cod_vino
    """)

    ids_vinos_ingreso = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_ingresos or not ids_vinos_ingreso:
        raise ValueError(
            "Faltan ingresos o vinos para generar renglones."
        )

    renglones_ingreso = []

    for codigo_ingreso in ids_ingresos:

        cantidad_vinos = random.randint(
            1,
            min(5, len(ids_vinos_ingreso))
        )

        vinos_elegidos = random.sample(
            ids_vinos_ingreso,
            cantidad_vinos
        )

        for cod_vino in vinos_elegidos:
            renglones_ingreso.append((
                codigo_ingreso,
                cod_vino,
                random.randint(10, 500)
            ))

    execute_values(
        cur,
        """
        INSERT INTO renglon_ingreso
        (
            codigo_ingreso,
            cod_vino,
            cantidad
        )
        VALUES %s
        ON CONFLICT (codigo_ingreso, cod_vino)
        DO NOTHING
        """,
        renglones_ingreso,
        page_size=1000
    )

    print(
        f"✓ Renglones de ingreso generados: "
        f"{len(renglones_ingreso)}"
    )

    """
    Este bloque se encarga de:
    - Obtener los ingresos y vinos existentes.
    - Asignar entre 1 y 5 vinos a cada ingreso.
    - Generar cantidades positivas de botellas.
    - Evitar repetir un vino dentro del mismo ingreso.
    - Insertar los renglones por lotes.
    """

    
    # 8. TRANSFERENCIAS

    cur.execute("""
        SELECT id_sala
        FROM sala_venta
        ORDER BY id_sala
    """)

    ids_salas_transferencia = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_salas_transferencia:
        raise ValueError(
            "No existen salas para generar transferencias."
        )

    transferencias = []

    for i in range(150):

        id_sala = ids_salas_transferencia[
            i % len(ids_salas_transferencia)
        ]

        fecha_confeccion = (
            FECHA_REFERENCIA_FIJA
            - timedelta(days=random.randint(0, 365))
        )

        transferencias.append((
            id_sala,
            fecha_confeccion,
            "en_confeccion"
        ))

    execute_values(
        cur,
        """
        INSERT INTO transferencia
        (
            id_sala,
            fecha_confeccion,
            estado
        )
        VALUES %s
        """,
        transferencias,
        page_size=1000
    )

    print(
        f"✓ Transferencias generadas: "
        f"{len(transferencias)}"
    )

    """
    Este bloque se encarga de:
    - Generar 150 solicitudes de transferencia.
    - Relacionar cada solicitud con una sala existente.
    - Asignar fechas de confección.
    - Mantener las solicitudes en estado inicial.
    - Insertar las transferencias por lotes.
    """

    
    # 9. STOCK_SALA
    
    cur.execute("""
        SELECT id_sala
        FROM sala_venta
        ORDER BY id_sala
    """)

    ids_salas_stock = [
        fila[0] for fila in cur.fetchall()
    ]

    cur.execute("""
        SELECT cod_vino
        FROM vino
        ORDER BY cod_vino
    """)

    ids_vinos_stock_sala = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_salas_stock or not ids_vinos_stock_sala:
        raise ValueError(
            "Faltan salas o vinos para inicializar el stock."
        )

    registros_stock_sala = [
        (id_sala, cod_vino, 0)
        for id_sala in ids_salas_stock
        for cod_vino in ids_vinos_stock_sala
    ]

    execute_values(
        cur,
        """
        INSERT INTO stock_sala
        (
            id_sala,
            cod_vino,
            cantidad
        )
        VALUES %s
        ON CONFLICT (id_sala, cod_vino) DO NOTHING
        """,
        registros_stock_sala,
        page_size=1000
    )

    print(
        f"✓ Registros de stock por sala generados: "
        f"{len(registros_stock_sala)}"
    )

    """
    Este bloque se encarga de:
    - Obtener las salas de venta y los vinos existentes.
    - Crear un registro de inventario por sala y vino.
    - Inicializar las cantidades en cero.
    - Evitar registros duplicados.
    - Preparar el stock para futuras transferencias.
    
    """

    
    # 10. COMPROBANTES
    
    cur.execute("""
        SELECT id_cliente
        FROM cliente
        ORDER BY id_cliente
    """)

    ids_clientes_comprobante = [
        fila[0] for fila in cur.fetchall()
    ]

    cur.execute("""
        SELECT id_sala
        FROM sala_venta
        ORDER BY id_sala
    """)

    ids_salas_comprobante = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_clientes_comprobante or not ids_salas_comprobante:
        raise ValueError(
            "Faltan clientes o salas para generar comprobantes."
        )

    comprobantes = []

    for _ in range(200):

        fecha_venta = (
            FECHA_REFERENCIA_FIJA
            - timedelta(days=random.randint(0, 365))
        )

        comprobantes.append((
            datetime.combine(
                fecha_venta,
                datetime.min.time()
            ),
            random.choice(ids_clientes_comprobante),
            random.choice(ids_salas_comprobante),
            Decimal("0.00"),
            Decimal("0.00"),
            Decimal("0.00")
        ))

    execute_values(
        cur,
        """
        INSERT INTO comprobante
        (
            fecha,
            id_cliente,
            id_sala,
            subtotal,
            descuento,
            total
        )
        VALUES %s
        """,
        comprobantes,
        page_size=1000
    )

    print(
        f"✓ Encabezados de comprobantes generados: "
        f"{len(comprobantes)}"
    ) 

    """
    Este bloque se encarga de:
    - Generar 200 encabezados de comprobantes.
    - Asignar un cliente y una sala a cada comprobante.
    - Registrar fechas de operaciones.
    - Inicializar los importes en cero.
    - Preparar los comprobantes para sus renglones.
    
    """

    
    # 11. AUDITORÍA DE PRECIOS
    
    cur.execute("""
        SELECT COUNT(*)
        FROM auditoria_precio
    """)

    cantidad_auditorias = cur.fetchone()[0]

    print(
        f"✓ Registros de auditoría existentes: "
        f"{cantidad_auditorias}"
    )

    print("✓ Nivel 2 finalizado")

    """
    Este bloque se encarga de:
    - Consultar los registros de auditoría existentes.
    - Evitar generar auditorías ficticias.
    - Reservar la generación automática para el trigger.
    - Preparar la verificación posterior de cambios de precios.
    """

    
def generar_carga_nivel_3(cur):
    # NIVEL 3
    """
    Este nivel se encargará de:
    - Generar análisis de calidad de los lotes de uva.
    - Registrar los vinos solicitados en transferencias.
    - Registrar los productos vendidos en comprobantes.
    - Respetar las relaciones con los niveles anteriores.
    """
    print("\n--- Cargando Nivel 3 ---")

    
    # 1. ANÁLISIS DE CALIDAD

    cur.execute("""
        SELECT nro_lote, fecha_cosecha
        FROM lote_uva
        ORDER BY nro_lote
    """)

    lotes_disponibles = cur.fetchall()

    if not lotes_disponibles:
        raise ValueError(
            "No existen lotes de uva para generar análisis."
        )

    analisis = []

    for nro_lote, fecha_cosecha in lotes_disponibles:

        cantidad_analisis = random.randint(1, 3)

        for _ in range(cantidad_analisis):

            fecha_analisis = (
                fecha_cosecha
                + timedelta(days=random.randint(0, 15))
            )

            grado_brix = Decimal(
                str(round(random.uniform(18, 26), 2))
            )

            ph = Decimal(
                str(round(random.uniform(3.0, 4.0), 2))
            )

            acidez_total = Decimal(
                str(round(random.uniform(4.0, 9.0), 2))
            )

            analisis.append((
                nro_lote,
                fecha_analisis,
                grado_brix,
                ph,
                acidez_total
            ))

    execute_values(
        cur,
        """
        INSERT INTO analisis_calidad
        (
            nro_lote,
            fecha,
            grado_brix,
            ph,
            acidez_total
        )
        VALUES %s
        """,
        analisis,
        page_size=1000
    )

    print(
        f"✓ Análisis de calidad generados: "
        f"{len(analisis)}"
    )

    """
    Este bloque se encarga de:
    - Obtener los lotes de uva existentes.
    - Generar entre 1 y 3 análisis por lote.
    - Registrar fecha, grado Brix, pH y acidez total.
    - Relacionar cada análisis con su lote.
    - Insertar los análisis por lotes.
    """

    
    # 2. RENGLONES DE TRANSFERENCIA

    cur.execute("""
        SELECT numero_solicitud
        FROM transferencia
        WHERE estado = 'en_confeccion'
        ORDER BY numero_solicitud
    """)

    ids_transferencias = [
        fila[0] for fila in cur.fetchall()
    ]

    cur.execute("""
        SELECT cod_vino
        FROM vino
        ORDER BY cod_vino
    """)

    ids_vinos_transferencia = [
        fila[0] for fila in cur.fetchall()
    ]

    if not ids_transferencias or not ids_vinos_transferencia:
        raise ValueError(
            "Faltan transferencias o vinos para generar renglones."
        )

    renglones_transferencia = []

    for numero_solicitud in ids_transferencias:

        cantidad_vinos = random.randint(
            1,
            min(5, len(ids_vinos_transferencia))
        )

        vinos_elegidos = random.sample(
            ids_vinos_transferencia,
            cantidad_vinos
        )

        for cod_vino in vinos_elegidos:
            renglones_transferencia.append((
                numero_solicitud,
                cod_vino,
                random.randint(1, 50)
            ))

    execute_values(
        cur,
        """
        INSERT INTO renglon_transferencia
        (
            numero_solicitud,
            cod_vino,
            cantidad
        )
        VALUES %s
        ON CONFLICT (numero_solicitud, cod_vino)
        DO NOTHING
        """,
        renglones_transferencia,
        page_size=1000
    )

    print(
        f"✓ Renglones de transferencia generados: "
        f"{len(renglones_transferencia)}"
    )

    """
    Este bloque se encarga de:
    - Obtener las transferencias pendientes y los vinos existentes.
    - Asignar entre 1 y 5 vinos a cada transferencia.
    - Generar cantidades positivas de botellas.
    - Evitar vinos duplicados dentro de una transferencia.
    - Insertar los renglones por lotes.
    """

    
    # 3. RENGLONES DE COMPROBANTE

    cur.execute("""
        SELECT COUNT(*)
        FROM stock_sala
        WHERE cantidad > 0
    """)

    productos_con_stock = cur.fetchone()[0]

    if productos_con_stock == 0:
        print(
            "⚠ Renglones de comprobante pendientes: "
            "todavía no hay stock disponible en las salas."
        )
    else:
        print(
            f"✓ Productos con stock disponibles: "
            f"{productos_con_stock}"
        )

        """
        Este bloque se encarga de:
        - Comprobar la disponibilidad de mercadería.
        - Evitar registrar ventas sin stock.
        - Preparar la carga de los productos vendidos.
        - Mantener la coherencia del inventario.
        """

    print("✓ Nivel 3 finalizado")



































def ejecutar_carga_masiva():
    print("Iniciando proceso de carga masiva...")
    try:
        with psycopg2.connect(**DB_CONFIG) as conn:
            with conn.cursor() as cur:
                generar_carga_nivel_0(cur)
                generar_carga_nivel_1(cur)
                # Confirmar transacción
                conn.commit()
                print("\n¡Nivel 0 completado exitosamente y cambios guardados en la BD!")
                
    except Exception as e:
        print(f"\n❌ Error de conexión o durante la carga: {e}")
        print("💡 Consejo: Asegúrate de que PostgreSQL esté corriendo en tu PC y que el usuario/contraseña sean correctos.")

if __name__ == "__main__":
    ejecutar_carga_masiva()




