# H1 · Justificación de normalización y decisiones de diseño

Responsable: Santiago. Base revisada: `001_esquema.sql` del commit
`b24d20e930dea300b8f8bdebdb5860408453bf33`. Esta revisión describe el modelo
implementado y distingue las decisiones justificadas de los controles pendientes.

## Dependencias funcionales

`X → Y` significa que un valor de X determina un único valor de Y. Los atributos
no clave de cada fila dependen de su clave completa, salvo las redundancias
monetarias expresamente identificadas más abajo.

| Relación | Determinante | Atributos determinados / decisión |
|---|---|---|
| localidad | codigo_postal | nombre, provincia, encargado_regional |
| sala_venta | id_sala | dirección, día de cierre, codigo_postal |
| empleado | cuit | nombre, fecha_ingreso, salario, id_sala |
| finca | id_finca | nombre, superficie_ha, departamento, provincia |
| parcela | (id_finca, nro_parcela) | superficie_ha, anio_plantacion, id_cepa |
| lote_uva | nro_lote; alternativamente (id_finca, nro_parcela, campana) | fecha_cosecha, kg_cosechados, bodega destino; la clave alternativa requiere integrar el UNIQUE de 002 de Valentina |
| analisis_calidad | id_analisis | lote, fecha, Brix, pH, acidez |
| bodega | cuit | razón social, domicilio |
| cepa | id_cepa; nombre UNIQUE | nombre y tipo |
| vino | cod_vino | nombre, tipo, añada, presentación, graduación, precio, bodega |
| composicion_vino | (cod_vino, id_cepa) | porcentaje |
| maridaje | id_maridaje; nombre UNIQUE | nombre y temperatura sugerida |
| vino_maridaje | (cod_vino, id_maridaje) | relación sin atributos adicionales |
| cliente | id_cliente; nro_doc UNIQUE actual | identidad, dirección, localidad, alta, tipo y descuento vigente |
| cliente_socio | id_cliente | pertenencia al subtipo |
| cliente_distribuidor | id_cliente; nro_habilitacion UNIQUE | zona y habilitación |
| cliente_exportador | id_cliente | país principal |
| permiso_exportacion | cod_permiso | exportador, emisión, vencimiento |
| transportista | codigo_transportista; cuit UNIQUE | razón social, correo, teléfono, domicilio |
| transportista_cobertura | (codigo_transportista, codigo_postal) | relación sin atributos adicionales |
| ingreso | codigo_ingreso | fecha, estado, transportista, bodega |
| renglon_ingreso | (codigo_ingreso, cod_vino) | cantidad |
| transferencia | numero_solicitud | sala, fecha, estado |
| renglon_transferencia | (numero_solicitud, cod_vino) | cantidad |
| stock_deposito | cod_vino | cantidad |
| stock_sala | (id_sala, cod_vino) | cantidad |
| comprobante | numero_comprobante | fecha, cliente, sala y resumen monetario |
| renglon_comprobante | (numero_comprobante, cod_vino) | cantidad, precio histórico, descuento monetario y neto |
| auditoria_precio | id_auditoria | vino, precios, fecha, usuario |

## Primera, segunda y tercera forma normal

**1FN.** Cada columna contiene un valor de su dominio. Cepas, maridajes,
permisos y renglones se representan como filas relacionadas, no como listas en
una columna. El JSON de `vw_ficha_vino` es solamente una representación de lectura.

**2FN.** En las claves compuestas, los atributos dependen del par completo:
la cantidad de stock depende de sala y vino; el porcentaje depende de vino y cepa;
la superficie de una parcela depende de finca y número de parcela. No se guardan
nombre del vino o dirección de la sala dentro de esas tablas intermedias.

**3FN del núcleo.** El encargado pertenece a localidad. Guardarlo también en sala
introduciría `id_sala → codigo_postal → encargado`. La razón social de la bodega
se consulta por FK, sin copiarla en vino. Los atributos de cliente se separan de
sus ventas y los de cepa se separan de parcela y composición.

No se afirma que toda columna física sea estrictamente 3FN: la consigna pide
almacenar importes derivados. En comprobante, `subtotal, descuento → total`;
en renglón, `cantidad, precio_unitario, descuento → subtotal`. Son redundancias
controladas que exigen triggers RN-08; hoy esos triggers todavía no existen.
`fn_total_comprobante` proporciona el cálculo, pero por sí sola no impide que
alguien escriba importes inconsistentes directamente.

## Decisiones

- **Jerarquía:** supertipo `cliente` más tres tablas de subtipos. Evita columnas
  nulas de país/habilitación en tipos incompatibles y permite que los permisos
  referencien solamente exportadores. Cuesta joins adicionales. Las FK actuales
  no garantizan exclusividad, totalidad ni concordancia con `tipo_cliente`;
  el equipo debe implementar ese control diferido o revisar el mapeo.
- **Claves naturales:** CUIT de bodega y empleado es identificador del dominio;
  `cuit_dom` valida once dígitos, no el dígito verificador. CUIT de transportista
  es UNIQUE con PK subrogada. Código postal como PK supone una localidad por
  código; es una simplificación del TPI, no una afirmación geográfica general.
  Si el catálogo contiene dos localidades con el mismo CP, incorporar un ID.
- **Claves subrogadas:** identidades para vino, clientes, salas, fincas, lotes y
  movimientos evitan propagar nombres editables como FK. Parcela conserva su
  identidad débil `(finca, número)`; la PK de stock de depósito refleja un único depósito.
- **Dinero:** NUMERIC conserva exactitud decimal. Cantidad entera para botellas;
  DATE para fechas civiles, TIMESTAMP para comprobantes/auditoría, ENUM para estados.
  El TIMESTAMP actual no guarda zona horaria: definirla al desplegar.
- **Precio histórico:** un renglón guarda el precio vigente al vender; no depende
  del precio actual de `vino`. La bonificación guardada es un importe monetario,
  no una tasa. U1 es una operación explícita de recálculo, no el comportamiento
  normal de una consulta histórica.
- **Descuentos:** la decisión acordada almacena la tasa vigente en cliente.descuento
  (002 de Valentina). id_cliente determina descuento; tipo_cliente ya no determina
  por sí solo la tasa vigente porque U6 permite 0.35 para determinados exportadores.
  Por eso no se trata simplemente de copiar una tasa derivada del tipo. Las tasas
  base 0.10/0.20/0.30 se asignan al crear o cambiar de tipo; U6 es una actualización
  explícita. Agregar/quitar permisos no recalcula la tasa ni las ventas históricas.
  La asignación automática requiere el trigger de Sol, aún pendiente de integrar.
- **FK:** RESTRICT conserva referencias a vino, bodega, transportista y sala con
  movimientos. CASCADE en renglones/subtipos/asociaciones elimina dependientes
  de su propietario. El DDL omite ON UPDATE: PostgreSQL usa NO ACTION; se asume
  que las claves no se editan. No se describe como CASCADE algo que no está escrito.

## Revisiones para integrar con Renata, Valentina y Sol

1. Integrar y probar 002 de Valentina: incorpora UNIQUE de parcela/campaña y
   vino/bodega/nombre/añada/presentación y CHECK avanzados ausentes del DDL inicial.
2. `cliente.localidad` es texto sin FK; no asegura que exista en el catálogo.
   Evaluar sustituirlo por código/ID sin perder los datos ya cargados.
3. `nro_doc` UNIQUE es más restrictivo que `(tipo_doc, nro_doc)`; decidir según
   el alcance de los documentos admitidos.
4. La provincia no se deduce del nombre del departamento: nombres pueden repetirse.
   Un catálogo geográfico permitiría validar pares, sin inventar esa dependencia.
5. Auditar `ON DELETE CASCADE` de auditoría de precios: podría perder historial
   cuando se borra un vino sin otros movimientos. Acordar retención con el equipo.
6. Coordinar D5 (borrar ingresos procesados) con RN-12 (bloquear sus renglones).
   Un trigger demasiado estricto puede bloquear también el borrado por cascada.

Estos pendientes impiden declarar cerrado H1/H2 para el grupo, aunque esta
justificación y las rutinas de Santiago estén disponibles para revisión.
