# Modelo relacional vigente

Fuente: mismo catalogo y commit que `diccionario_datos.md`. Las PK y UNIQUE figuran en el diccionario. Este inventario de relaciones complementa el DER PDF anterior.

| Tabla dependiente | Relacion y accion referencial |
|---|---|
| analisis_calidad | FOREIGN KEY (nro_lote) REFERENCES lote_uva(nro_lote) ON DELETE CASCADE |
| auditoria_precio | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE CASCADE |
| cliente_distribuidor | FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE |
| cliente_exportador | FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE |
| cliente_socio | FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE |
| composicion_vino | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE CASCADE |
| composicion_vino | FOREIGN KEY (id_cepa) REFERENCES cepa(id_cepa) ON DELETE RESTRICT |
| comprobante | FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT |
| comprobante | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT |
| empleado | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT |
| ingreso | FOREIGN KEY (codigo_transportista) REFERENCES transportista(codigo_transportista) ON DELETE RESTRICT |
| ingreso | FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) ON DELETE RESTRICT |
| lote_uva | FOREIGN KEY (cuit_bodega_destino) REFERENCES bodega(cuit) ON DELETE RESTRICT |
| lote_uva | FOREIGN KEY (id_finca, nro_parcela) REFERENCES parcela(id_finca, nro_parcela) ON DELETE RESTRICT |
| parcela | FOREIGN KEY (id_cepa) REFERENCES cepa(id_cepa) ON DELETE RESTRICT |
| parcela | FOREIGN KEY (id_finca) REFERENCES finca(id_finca) ON DELETE CASCADE |
| permiso_exportacion | FOREIGN KEY (id_cliente_exportador) REFERENCES cliente_exportador(id_cliente) ON DELETE CASCADE |
| renglon_comprobante | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT |
| renglon_comprobante | FOREIGN KEY (numero_comprobante) REFERENCES comprobante(numero_comprobante) ON DELETE CASCADE |
| renglon_ingreso | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT |
| renglon_ingreso | FOREIGN KEY (codigo_ingreso) REFERENCES ingreso(codigo_ingreso) ON DELETE CASCADE |
| renglon_transferencia | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT |
| renglon_transferencia | FOREIGN KEY (numero_solicitud) REFERENCES transferencia(numero_solicitud) ON DELETE CASCADE |
| sala_venta | FOREIGN KEY (codigo_postal) REFERENCES localidad(codigo_postal) ON DELETE RESTRICT |
| stock_deposito | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT |
| stock_sala | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE RESTRICT |
| stock_sala | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT |
| transferencia | FOREIGN KEY (id_sala) REFERENCES sala_venta(id_sala) ON DELETE RESTRICT |
| transportista_cobertura | FOREIGN KEY (codigo_postal) REFERENCES localidad(codigo_postal) ON DELETE RESTRICT |
| transportista_cobertura | FOREIGN KEY (codigo_transportista) REFERENCES transportista(codigo_transportista) ON DELETE CASCADE |
| vino | FOREIGN KEY (cuit_bodega) REFERENCES bodega(cuit) ON DELETE RESTRICT |
| vino_maridaje | FOREIGN KEY (cod_vino) REFERENCES vino(cod_vino) ON DELETE CASCADE |
| vino_maridaje | FOREIGN KEY (id_maridaje) REFERENCES maridaje(id_maridaje) ON DELETE RESTRICT |
