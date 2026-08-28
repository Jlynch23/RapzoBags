# Rapzo QoL — Codex Handoff / Estado del proyecto

> **LEER PRIMERO junto con `AGENTS.md` antes de tocar código.**
>
> Este documento describe el estado del addon inmediatamente después del snapshot de código
> **`3a610b1`** (`art(branding): use Rapzo shield addon icon`), en la rama
> **`feature/afk-screen-alpha5`**, el 2026-08-28.
>
> Si el código actual y este documento difieren, **el código actual es la fuente de verdad**.
> Después de un cambio importante, actualizar este handoff.

---

## 1. Qué es Rapzo QoL

Rapzo QoL es un **solo addon modular** para World of Warcraft Retail.

WoW debe ver únicamente esta carpeta:

```text
RapzoQoL/
```

No volver a separar los módulos en addons `RapzoBags_*`. La migración a un único addon ya está hecha.

Versión actual:

```text
Rapzo QoL 3.0.0-alpha5
WoW Retail Interface: 120100
SavedVariables: RapzoBagsDB
```

Se conserva deliberadamente el nombre histórico `RapzoBagsDB` para no perder inventario,
personajes ni preferencias guardadas.

---

## 2. Rama de desarrollo y reglas importantes

Rama de trabajo actual:

```text
feature/afk-screen-alpha5
```

Reglas que no se deben romper:

1. Leer `AGENTS.md`.
2. Preservar funciones que ya trabajan.
3. **HUD V1 no se elimina.** Los experimentos visuales deben entrar como estilos seleccionables.
4. El HUD V2 debe seguir siendo seleccionable sin crear un segundo sistema paralelo.
5. Mantener el modelo de **un solo addon**.
6. No renombrar `RapzoBagsDB`.
7. Para HUD visual, mantener cuando sea posible:
   - preview HTML offline en `preview/index.html`;
   - preview dentro de WoW con frames falsos/demo.
8. Antes de modificar HUD, revisar todos los archivos de `RapzoQoL/Modules/HUD/`; existen hooks,
   reanclajes y correcciones repartidas entre varios archivos.
9. Evitar duplicar cast bars, AuraContainers, hooks o familias de eventos.
10. Antes de terminar una tarea, revisar diff, rama y estado de Git.

---

## 3. Orden real de carga

Definido por `RapzoQoL/RapzoQoL.toc`:

```text
Core/Core.lua
Core/Scanner.lua

Modules/Tooltip/Tooltip.lua
Modules/Search/Search.lua
Modules/Collections/Collections.lua
Modules/Vendor/Vendor.lua
Modules/AFK/AFK.lua
Modules/AFK/AFKBrand.lua

Modules/HUD/HUD.lua
Modules/HUD/HUDFixes.lua
Modules/HUD/HUDStyles.lua
Modules/HUD/ClassResources.lua
Modules/HUD/AuraAnchors.lua
Modules/HUD/HUDPreview.lua

Config/Config.lua
```

Media actual:

```text
RapzoQoL/Media/RapzoQoL-Icon.png
```

El TOC usa:

```text
## IconTexture: Interface\AddOns\RapzoQoL\Media\RapzoQoL-Icon
```

La dirección visual elegida para el branding es el **escudo Rapzo** dorado/azul.

---

## 4. Mapa del proyecto

| Archivo | Responsabilidad |
|---|---|
| `Core/Core.lua` | namespace global, SavedVariables, módulos, comandos, accent color, datos de personajes, aliases y `/rl` |
| `Core/Scanner.lua` | escaneo de bolsas, equipo, banco y bancos compatibles |
| `Modules/Tooltip/Tooltip.lua` | metadata de ítems, expansión, tipo, Item ID y cantidades/localizaciones |
| `Modules/Search/Search.lua` | buscador global de inventario y vista de oro |
| `Modules/Collections/Collections.lua` | detección obtenido/no obtenido para coleccionables |
| `Modules/Vendor/Vendor.lua` | merchant extendido, grid, filtros, marcas y cantidades |
| `Modules/AFK/AFK.lua` | pantalla AFK fullscreen |
| `Modules/AFK/AFKBrand.lua` | branding/textos adicionales de AFK |
| `Modules/HUD/HUD.lua` | núcleo HUD: cursor, minimapa, unit displays |
| `Modules/HUD/HUDFixes.lua` | correcciones de frames Blizzard, castbars nativas, rest indicator y anchors |
| `Modules/HUD/HUDStyles.lua` | estilos V1/V2, castbars V2, auras y escala |
| `Modules/HUD/ClassResources.lua` | recursos secundarios de clase para V2 |
| `Modules/HUD/AuraAnchors.lua` | coordinación de auras nativas/propias |
| `Modules/HUD/HUDPreview.lua` | preview in-game de Player/Target/Focus |
| `Config/Config.lua` | panel propio + registro en ESC > Options > AddOns |
| `preview/index.html` | preview offline interactivo del HUD |

---

## 5. Core y base de datos

Namespace principal:

```lua
_G.RapzoQoL
```

Alias de compatibilidad:

```lua
_G.RapzoBags = _G.RapzoQoL
```

### SavedVariables principales

`RapzoBagsDB` mantiene:

- `schema`
- `characters`
- `account.bank`
- `settings`
- `settings.modules`
- `settings.theme.accent`
- configuraciones específicas de módulos, por ejemplo:
  - `settings.vendor`
  - `settings.afk`
  - `settings.hud`

Módulos registrados:

```text
tooltip
search
vendor
collections
afk
hud
config
```

### Accent Color

Color por defecto del core:

```text
RGB 0.22, 0.83, 0.98
```

El color se guarda en:

```text
RapzoBagsDB.settings.theme.accent
```

Funciones centrales:

- `RB:GetAccentColor()`
- `RB:SetAccentColor()`
- `RB:ResetAccentColor()`
- `RB:ApplyTheme()`

Los colores propios de clase del HUD deben seguir respetándose; el accent global no debe
reemplazar colores de clase donde el HUD usa `RAID_CLASS_COLORS`.

### Orden de bolsas

El core intenta mantener:

```lua
C_Container.SetSortBagsRightToLeft(false)
C_Container.SetInsertItemsLeftToRight(false)
```

y vuelve a aplicarlo con pequeños delays.

---

## 6. Scanner

`Core/Scanner.lua` recopila inventario conocido por personaje.

Escanea:

- bolsas;
- equipo equipado;
- banco/bancos disponibles;
- enlaces e Item IDs cuando están disponibles;
- cantidad por localización.

El Core después puede agregar por Item ID mediante:

- `RB:GetItemAggregate(itemID)`
- `RB:GetKnownItemLink(itemID)`
- `RB:GetAllKnownItemIDs()`
- `RB:GetTotalMoney()`

El buscador, tooltip y vendor dependen de estos datos.

---

## 7. Tooltip

Archivo:

```text
RapzoQoL/Modules/Tooltip/Tooltip.lua
```

Funciones actuales:

- Item ID;
- expansión del objeto;
- tipo/subtipo;
- cantidades guardadas;
- localización por personaje/banco;
- compatibilidad para evitar Item ID duplicado cuando otra UI como MUI también intenta añadirlo;
- evita apropiarse incorrectamente del tooltip del merchant cuando corresponde.

Ajustes principales:

- `settings.tooltip`
- `settings.showItemExpansion`
- `settings.showItemType`
- `settings.showItemID`
- localizaciones configurables desde slash commands.

---

## 8. Buscador global

Archivo:

```text
RapzoQoL/Modules/Search/Search.lua
```

UI principal actual:

```text
760 x 520
```

Permite:

- buscar por nombre;
- buscar por Item ID;
- listar ítems conocidos en todos los personajes/bancos;
- seleccionar un resultado y ver detalle;
- mostrar cantidades/localizaciones;
- mostrar oro guardado por personaje.

`/rapzo` abre el buscador por defecto si Search está activo.

---

## 9. Collections

Archivo:

```text
RapzoQoL/Modules/Collections/Collections.lua
```

Detecta estado de colección para los tipos soportados por las APIs disponibles:

- pets;
- mounts;
- toys;
- heirlooms;
- transmog sets;
- transmog/item appearances;
- recipes;
- housing cuando la API/tooltip permite determinarlo.

Tiene cache y `Collections:ClearCache()`.

Vendor usa este módulo para filtros y marcas de obtenido/no obtenido.

---

## 10. Vendor extendido

Archivo:

```text
RapzoQoL/Modules/Vendor/Vendor.lua
```

### Grid

Default:

```text
4 columnas x 5 filas
```

Rangos permitidos por código:

```text
columnas: 2..8
filas:    5..10
```

### Funciones

- expande MerchantFrame;
- crea/reutiliza slots adicionales;
- layout configurable;
- conserva/restaura dimensiones originales;
- reposiciona correctamente BuyBack;
- restaura layout al desactivar;
- muestra marca de coleccionado;
- muestra cantidad poseída;
- filtra merchant;
- mapea índices visibles a índices originales;
- envuelve APIs del merchant cuando el filtro está activo;
- refresca filtros y slots;
- detecta conflicto con Krowi Extended Vendor UI.

### Filtros actuales

```text
Todos
No obtenidos
Monturas
Transmog
Recetas
```

Config default:

- enabled: según módulo Vendor;
- markCollected: `true`;
- showOwnedCount: `true`;
- filterMode: `all`.

Este módulo ha tenido históricamente trabajo delicado de anchors/tamaño/BuyBack. Antes de tocar
MerchantFrame, revisar `CaptureOriginalLayout`, `RestoreDefaultMerchantLayout`,
`PositionMerchantBuyBackItem` y `LayoutMerchantSlots`.

---

## 11. Pantalla AFK

Archivos:

```text
Modules/AFK/AFK.lua
Modules/AFK/AFKBrand.lua
```

### Default actual

- enabled: según módulo AFK;
- opacity: `0.84`;
- timer: ON;
- character: ON;
- zone: ON;
- clock: ON;
- money: OFF;
- hideInCombat: ON.

Panel central actual:

```text
880 x 560
```

La pantalla muestra según configuración:

- branding RAPZO QoL;
- indicador AFK;
- personaje;
- especialización/detalles;
- zona;
- tiempo AFK;
- reloj;
- dinero si se habilita;
- footer.

Branding adicional actual incluye:

```text
Quality of life, the Rapzo way.
```

Existe modo preview sin tener que quedar AFK realmente.

---

# 12. HUD — ESTADO IMPORTANTE

El HUD es actualmente la zona más sensible del addon.

Archivos que deben revisarse juntos:

```text
HUD.lua
HUDFixes.lua
HUDStyles.lua
ClassResources.lua
AuraAnchors.lua
HUDPreview.lua
```

## 12.1 Partes del HUD

El módulo controla:

- cursor visual;
- minimapa cuadrado;
- Player frame visual;
- Target frame visual;
- Focus frame visual;
- estilos V1/V2;
- auras V2;
- castbars V2;
- recursos secundarios de clase V2;
- preview.

Config defaults del núcleo HUD:

```text
enabled        = ON
cursor         = ON
squareMinimap  = ON
unitFrames     = ON
cursorSize     = 52
```

Cursor:

```text
rango permitido: 36..96 px
visual version actual: 3
```

## 12.2 Estilo V1 — Clásico

**Debe preservarse.**

Dimensión base:

```text
240 x 64
```

V1 representa el diseño anterior/estable de Rapzo QoL.

Regla crítica actual:

**V1 conserva las cast bars de Blizzard.**

`HUDFixes.lua` está preparado para que la supresión de castbars nativas sea reversible y solo
se active cuando corresponde a V2.

No volver a ocultar castbars nativas incondicionalmente.

## 12.3 Estilo V2 — ToxiUI

Selector interno:

```text
style = 2
```

Geometría base actual:

```text
STYLE2_WIDTH  = 150
STYLE2_HEIGHT = 43
```

Escala default:

```text
1.50x
```

Rango de escala:

```text
0.50x .. 2.50x
```

A escala default, la huella aproximada base es:

```text
225 x 65 px
```

La escala se guarda en:

```text
RapzoBagsDB.settings.hud.frameScale
```

V2 actual busca ser compacto y Toxi-like:

- sin icono de portrait como elemento dominante;
- sin panel/borde exterior decorativo;
- nombre arriba;
- health como barra visual principal;
- power fino;
- colores correctos de clase;
- auras arriba;
- castbar abajo;
- recursos secundarios del player cuando correspondan.

### Auras V2

Tamaño base de aura:

```text
16 px
```

Ancho de fila:

```text
150 px
```

Para V2, Rapzo QoL gestiona sus AuraContainers y evita que la tira nativa mezclada de
Target/Focus aparezca duplicada.

V1 mantiene el comportamiento nativo correspondiente.

### Cast bars V2

V2 crea una `RapzoQoLCastBar` por display.

Altura visual configurada por el estilo:

```text
10 px
```

Regla crítica:

- V2: castbars propias Rapzo; castbars nativas Blizzard se ocultan de forma reversible.
- V1: castbars nativas Blizzard deben quedar disponibles.

`HUDFixes.lua` contiene `syncNativeUnitCastBars()`.
No crear otra segunda rutina paralela para ocultar castbars.

El histórico inmediato del proyecto incluye un problema de **múltiples cast bars visibles**.
El código actual ya contiene la estrategia para evitarlo; cualquier modificación debe comprobar
que siga existiendo exactamente la cantidad esperada.

## 12.4 Recursos secundarios V2

Archivo:

```text
ClassResources.lua
```

Geometría base:

```text
RESOURCE_WIDTH  = 150
RESOURCE_HEIGHT = 6
RESOURCE_GAP    = 3
```

Recursos soportados actualmente:

- Rogue — Combo Points;
- Feral Druid (spec 103) — Combo Points;
- Warlock — Soul Shards con precisión parcial;
- Paladin — Holy Power;
- Windwalker Monk (spec 269) — Chi;
- Arcane Mage (spec 62) — Arcane Charges;
- Evoker — Essence;
- Death Knight — 6 Runes con progreso de recarga.

Si la clase/spec no tiene un recurso discreto soportado, no debe quedar una fila vacía inútil.

Para Player, si el recurso secundario está visible, la castbar se ancla debajo del recurso;
si no, se ancla debajo del display.

## 12.5 Anchors y correcciones

`HUDFixes.lua`:

- detecta castbars nativas de Player/Target/Focus;
- las oculta solo en V2;
- restaura comportamiento en V1;
- oculta arte nativo de resting que no se quiere;
- mantiene un indicador de rest propio;
- aplica anchors de displays;
- re-sincroniza después de hooks/eventos Blizzard.

`AuraAnchors.lua`:

- coordina Target/Focus;
- V2 evita duplicados de auras nativas;
- V1 conserva comportamiento nativo;
- tiene guards para evitar reentrada de anchoring.

No hacer anchors adicionales en otro archivo sin comprobar primero estos dos.

---

## 13. Preview HUD

### Dentro de WoW

Archivo:

```text
HUDPreview.lua
```

Frame:

```text
RapzoQoLHUDPreviewFrame
920 x 560
```

Crea demos falsos para:

- Player;
- Target;
- Focus.

Permite:

- cambiar Estilo 1 / Estilo 2;
- ajustar escala V2;
- ver tamaño aproximado;
- iterar visualmente sin target/focus real.

El preview V2 usa actualmente la misma base:

```text
150 x 43
```

y escala guardada por `HUD:GetFrameScale()`.

### Offline

```text
preview/index.html
```

Es una herramienta visual independiente de WoW.

Debe mantenerse alineada con la geometría real cuando se cambien dimensiones de HUD.

---

## 14. Configuración dentro de Blizzard Options

Archivo:

```text
Config/Config.lua
```

Rapzo QoL se registra en:

```text
ESC > Options > AddOns > Rapzo QoL
```

También existe el panel propio antiguo/completo.

El panel de Blizzard actualmente permite:

- Accent Color;
- Tooltip avanzado;
- Expansión del objeto;
- Tipo + Item ID;
- Buscador global;
- Coleccionables;
- Vendedor extendido;
- Pantalla AFK;
- HUD visual;
- **V1 - Clásico**;
- **V2 - ToxiUI**;
- Reescanear;
- abrir panel completo.

El selector V1/V2 usa directamente:

```lua
HUD:GetStyle()
HUD:SetStyle(style)
```

No reemplazarlo por otro estado independiente.

`/rapzo config` y `/rapzo options` intentan abrir directamente la categoría de Rapzo QoL en
Blizzard Settings y usan fallback al panel propio cuando hace falta.

---

## 15. Comandos

Aliases principales:

```text
/rapzo
/rqol
/rbags
/rapzobags
```

Reload rápido:

```text
/rl
```

Comandos Core:

```text
/rapzo scan
/rapzo status
/rapzo modules
/rapzo color #RRGGBB
/rapzo color reset
/rapzo help
/rapzo ayuda
/rapzo reset confirm
```

Tooltip:

```text
/rapzo tooltip ...
/rapzo expansion ...
/rapzo itemtype ...
/rapzo tipo ...
/rapzo itemid ...
/rapzo id ...
/rapzo locations ...
```

Search:

```text
/rapzo search <texto>
/rapzo find <texto>
/rapzo gold
```

Collections:

```text
/rapzo collections on|off|clear
```

Vendor:

```text
/rapzo vendor ...
```

Incluye control de:

- status;
- on/off;
- grid;
- filtros;
- marcas según lo implementado en `Vendor:HandleSlash()`.

AFK:

```text
/rapzo afk status
/rapzo afk on
/rapzo afk off
/rapzo afk preview
/rapzo afk hide
```

HUD:

```text
/rapzo hud status
/rapzo hud debug
/rapzo hud on|off
/rapzo hud cursor on|off
/rapzo hud cursorsize <36-96>
/rapzo hud minimap on|off
/rapzo hud frames on|off
/rapzo hud style 1|2
/rapzo hud scale <0.50-2.50>
/rapzo hud preview
/rapzo hud preview on|off
```

---

## 16. Últimos cambios relevantes antes de este handoff

Orden de más reciente a más antiguo:

```text
3a610b1  art(branding): use Rapzo shield addon icon
0fb5d7b  feat(hud): compact Toxi frames and add addon icon
44551dd  fix(hud): restore V1 cast bars and style selector
330c8cb  feat(config): add HUD V1/V2 selector
6c60112  feat(config): add Rapzo QoL to Blizzard AddOns settings
5a45bf4  Add exact live scale slider to HUD preview
054b10b  Add live configurable HUD frame scale
30719b4  Scale Toxi HUD preview to 1.5x
c8c4aa8  Scale Toxi unit frames to 1.5x
206c341  Suppress Blizzard duplicate unit cast bars
130af3d  Update HUD preview to micro ToxiUI proportions
d2549a3  Match secondary resources to micro unit frames
```

Esto explica por qué el HUD tiene varias capas de compatibilidad: se estaba iterando rápidamente
sobre tamaño, escala, castbars y preservación de V1.

---

## 17. Estado exacto donde quedó el trabajo

Al crear este documento, el código ya contiene:

- Rapzo QoL como un solo addon.
- Branding Rapzo QoL.
- Icono de addon tipo **escudo Rapzo**.
- Accent Color configurable.
- Registro real en Blizzard `Options > AddOns`.
- selector visible V1/V2.
- V1 preservado.
- V2 ToxiUI compacto a base 150x43.
- escala V2 configurable, default 1.50.
- preview V1/V2 dentro de WoW.
- preview HTML offline.
- manejo explícito para evitar castbars duplicadas en V2.
- restauración de castbars Blizzard en V1.
- auras V2.
- recursos secundarios V2.
- cursor visual.
- minimapa cuadrado.
- AFK screen.
- Tooltip.
- búsqueda global.
- colecciones.
- merchant extendido.

### Qué NO debe asumir Codex

No asumir que algo está visualmente perfecto solo porque está implementado.

El código puede estar correcto estructuralmente y todavía requerir ajuste visual dentro de WoW.
Para HUD, las capturas y pruebas reales del usuario son la validación final.

No hacer un refactor masivo "por limpieza" antes de comprobar el comportamiento actual.

---

## 18. Checklist de prueba recomendado dentro de WoW

Después de cualquier cambio HUD/config:

1. `/rl`.
2. Abrir `ESC > Options > AddOns > Rapzo QoL`.
3. Confirmar que aparece el panel.
4. Cambiar V1 -> V2 -> V1.
5. Confirmar persistencia después de `/rl`.
6. En V1:
   - comprobar Player/Target/Focus;
   - comprobar que las castbars Blizzard siguen visibles/funcionales.
7. En V2:
   - comprobar Player/Target/Focus;
   - comprobar que no aparece arte exterior no deseado;
   - comprobar health/power;
   - comprobar auras;
   - comprobar exactamente una castbar por unidad cuando castea;
   - comprobar que no reaparecen castbars Blizzard duplicadas.
8. Probar `/rapzo hud preview`.
9. Probar escala V2.
10. Probar una clase con recurso secundario si el cambio toca `ClassResources.lua`.
11. Entrar/salir de combate si el cambio toca protected frames o AFK.
12. Abrir merchant si se tocó Vendor.
13. Revisar errores Lua antes de dar el cambio por terminado.

---

## 19. Flujo recomendado para Codex

Antes de empezar una tarea:

```bash
git status
git branch --show-current
git log -5 --oneline
```

Esperado:

```text
feature/afk-screen-alpha5
```

Para trabajo HUD:

1. leer este documento;
2. leer `AGENTS.md`;
3. inspeccionar los 6 archivos HUD antes de modificar;
4. explicar brevemente el diagnóstico;
5. modificar el mínimo conjunto necesario;
6. comprobar que no se creó un sistema paralelo;
7. revisar `git diff`;
8. indicar pruebas exactas dentro de WoW.

---

## 20. Principio de continuidad

**Rapzo QoL se está construyendo de forma incremental.**

La prioridad no es reescribirlo: es seguir avanzando desde el estado actual sin perder lo que ya
funciona.

En particular:

- V1 = referencia estable que se conserva.
- V2 = línea visual ToxiUI en desarrollo.
- Escudo Rapzo = branding actual.
- Config de Blizzard = entrada principal para opciones.
- `RapzoBagsDB` = continuidad de datos.
- `feature/afk-screen-alpha5` = rama activa mientras no se indique lo contrario.
