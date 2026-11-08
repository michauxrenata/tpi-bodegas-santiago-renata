# Integración revisada el 30/10/2026

Versiones leídas, sin modificar archivos de otras integrantes:

- Santiago: 87b2469e773b14dc9ada209c9b7b0c8d84913698, más este aporte.
- Valentina, etapa 2: 5cf3e0bedec0eac991428cb99526753706633c8e.
- Sol: ede9c69ad62cdb1df9ba30158965a815fd58469f.
- Valentina, carga: f8bbc39c6008a7d51d8cb8f617280d164e17deea.

## Bloqueos reproducidos

El diagnóstico `node tools/validacion_sql/revisar_integracion.mjs` crea una base
PGlite descartable. Lee esas versiones mediante git show y las funciones y
procedimientos locales de Santiago. No modifica 002, 005 ni 007.

1. **Sol / 005:** el RAISE de composición tiene dos argumentos y un solo marcador.
   El texto termina en `actualmente suma %%`: debe tener un marcador `%` para
   v_total. El `100%%` anterior sí representa el porcentaje literal.
   Resultado real: 42601, too many parameters specified for RAISE.
2. **Valentina / 007:** CALL como operador falla con 42501 en renglon_ingreso.
   El propietario técnico necesita UPDATE sobre las tablas renglon_ingreso y
   renglon_transferencia para ejecutar LOCK TABLE ... IN SHARE MODE. Conservar
   ese permiso sólo en el propietario, no en el operador, mientras exista ese lock.
3. **Flujo de estados / equipo:** el operador no puede pasar ingreso a terminado
   (42501). Definir una operación controlada para terminar ingresos/transferencias,
   que valide detalles; no conceder una actualización general que permita falsificar
   procesado. Revisar también el INSERT con estado explícito: los triggers de
   estados observados sólo cubren UPDATE.

Se verificó que el operador no puede actualizar stock_sala directamente.
Para aislar el diagnóstico de roles, se revierte la instalación de 005 antes de
probar permisos: esos CALL NO constituyen pruebas de integración con triggers.
El script termina con código 1 mientras encuentra bloqueos; es un diagnóstico,
no forma parte de npm test. Evidencia: evidencias/integracion_2026-10-30.txt.

## Próximos cambios por responsable

- Santiago entrega función basada en descuento persistido, U6, regresiones y
  contratos_datos.md actualizado. No cambia las firmas de 004.
- Sol: corregir compilación de 005; asignación base del descuento; ventas con
  importes históricos y permisos restringidos; bloqueo de cabeceras en RN-12.
- Valentina: integrar la última versión 004 de Santiago (su rama revisada aún
  contiene la anterior), completar permisos del propietario y revisar con Sol
  la propiedad/permisos de la función trigger de ventas.
- Equipo: probar migraciones completas y concurrencia en PostgreSQL de Docker,
  transición controlada de estados y regresión con el rol real de API.

## Límites de los siguientes hitos

La carga masiva revisada avanzó, pero su entrada principal sólo ejecuta niveles
0 y 1; no permite certificar aún un dataset operativo completo para H4. Santiago
mantiene los índices y scripts de EXPLAIN ya entregados como candidatos: no se
inventan mediciones finales. S9 aún requiere coordinar la vista con Valentina.
Las ramas revisadas no publican una base de API/frontend para integrar endpoints
ni catálogo sin sustituir decisiones de sus responsables. No hay un entorno de
nube identificado para ejecutar migraciones. README de instalación definitiva y
prueba con un comando dependen de cerrar primero esta integración.
