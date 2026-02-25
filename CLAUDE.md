# CinemaProject - Godot 4.5

## Ruta del proyecto
La ruta real del proyecto Godot es: `C:\Users\ivans\GIT\CinemaProject\proyecto-cine`
El repositorio git raíz está en: `C:\Users\ivans\GIT\CinemaProject`

**SIEMPRE trabajar sobre los archivos en `C:\Users\ivans\GIT\CinemaProject\proyecto-cine`**
**NO crear worktrees aislados** — el usuario gestiona git con Fork.

## Estructura del proyecto
```
proyecto-cine/
├── Scripts/
│   ├── Core/       # TextDB, DebugConfig, Utils, DayPlanDB
│   ├── Customer/   # Customer, CustomerDB, CustomerManager
│   ├── Game/       # DaySystem, FoodStation, InteractionController, MatchingSystem, MovieDB, RunState, TagDB, Tray
│   │   └── Food/   # DrinkStation, FoodController, FoodDB
│   ├── Main/       # Main.gd
│   ├── Tools/      # ProjectReport
│   └── UI/         # CustomerOrderHUD, DaySetupUI, HUD, StockHUD
├── Scenes/
│   ├── Main.tscn
│   └── Customer.tscn
├── Assets/         # Modelos 3D, posters, props
├── Audio/
├── Data/
├── Icons/
├── python/         # MCP server para Godot
└── addons/         # godot_mcp plugin
```

## Autoloads (project.godot)
- `TextDB` — textos localizados
- `DebugConfig` — configuración de debug
- `TagDB` — sistema de tags de películas
- `CustomerDB` — base de datos de clientes
- `DayPlanDB` — planificación de días
- `RunState` — estado de la partida en curso
- `MatchingSystemAuto` — sistema de matching cliente-película

## MCP Server
- Archivo: `python/server.py`
- Config: `proyecto-cine/.mcp.json`
- Requiere: `.venv` con `mcp`, `requests`, `python-dotenv`

## Convenciones
- Godot 4.5, GDScript
- Input action relevante: `serve_next` (tecla E)
- El usuario usa **Fork** para gestionar git — no hacer commits automáticos
