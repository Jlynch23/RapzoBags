RAPZO BAGS MODULAR v3.0.0-alpha3
=================================

Instalacion:
1. Borra/desactiva la carpeta antigua RapzoBags para no cargar dos versiones.
2. Copia las 6 carpetas RapzoBags_* dentro de World of Warcraft/_retail_/Interface/AddOns/.
3. En la pantalla de AddOns deja RapzoBags_Core activo siempre. Los otros son opcionales.

Modulos:
- RapzoBags_Core (OBLIGATORIO): DB, scanner, bolsas/banco/banco de guerra, orden de bolsas.
- RapzoBags_Tooltip: expansion, tipo, Item ID, cantidades/ubicaciones.
- RapzoBags_Search: buscador global visual.
- RapzoBags_Collections: obtenido/no obtenido para coleccionables.
- RapzoBags_Vendor: vendedor 4x5 y filtros. Usa Collections si esta cargado.
- RapzoBags_Config: /rbags config para apagar funciones sin quitar carpetas.

Comandos principales:
/rbags
/rbags config
/rbags modules
/rbags scan
/rbags search <texto>
/rbags vendor
/rbags tooltip on|off
/rbags expansion on|off
/rbags collections on|off

Notas:
- La base RapzoBagsDB se conserva al migrar desde la rama 2.x.
- Si desactivas RapzoBags_Collections, Vendor sigue ampliando la tienda y mostrando cantidades, pero no puede saber si un coleccionable esta obtenido.
- Implementacion propia; no incluye codigo de BagSync ni Krowi Extended Vendor UI.

alpha2:
- Icono nativo de bolsa visible en la lista de AddOns.
- Consulta ACTUALIZACIONES.txt para usar GitHub Releases + WowUp.

ICONO PERSONALIZADO
-------------------
Todos los modulos usan el mismo icono desde RapzoBags_Core\Media\RapzoBagsIcon.tga.
