# CURRENT_STATE — CinemaProject
_Generado: 2026-02-27_
_Godot 4.5 · GDScript · Proyecto en `C:\Users\ivans\GIT\CinemaProject\proyecto-cine`_

---

## Autoloads

Registrados en `project.godot` y disponibles globalmente en toda la sesión:

| Nombre | Script | Rol |
|--------|--------|-----|
| `TextDB` | `Scripts/Core/TextDB.gd` | Textos localizados (ES/EN) |
| `DebugConfig` | `Scripts/Core/DebugConfig.gd` | Flag global `ENABLE_DEBUG` |
| `SoundManager` | `Scripts/Core/SoundManager.gd` | Efectos de sonido |
| `TagDB` | `Scripts/Game/TagDB.gd` | Etiquetas de películas (label/color/is_selectable) |
| `CustomerDB` | `Scripts/Customer/CustomerDB.gd` | Generación de clientes y pedidos |
| `DayPlanDB` | `Scripts/Core/DayPlanDB.gd` | Construcción de la lista de clientes del día |
| `RunState` | `Scripts/Game/RunState.gd` | Estado persistente de la partida |
| `MatchingSystemAuto` | `Scripts/Game/MatchingSystem.gd` | Matching cliente-película |
| `StabilityManager` | `Scripts/Core/StabilityManager.gd` | Estabilidad del cine (0–100) |
| `EndingManager` | `Scripts/Game/EndingManager.gd` | Condiciones de final de partida |
| `StockManager` | `Scripts/Core/StockManager.gd` | Inventario de comida y bebida |
| `NPCRegistry` | `Scripts/Core/NPCRegistry.gd` | Definiciones y estado de NPCs |
| `SpecialRoom` | `Scripts/Game/SpecialRoom.gd` | Neutralizaciones de entidades |
| `ContaminationManager` | `Scripts/Game/ContaminationManager.gd` | Nivel de contaminación visual |
| `EventsManager` | `Scripts/Game/EventsManager.gd` | Eventos de fin de día (muertes) |
| `SaveManager` | `Scripts/Game/SaveManager.gd` | Guardado/carga JSON en disco |

---

## Loop principal de juego

### Flujo de una partida completa

```
MainMenu.tscn
  → Main.tscn se carga (Main.gd en _enter_tree: reset_run si partida nueva)
    → Main._ready: StabilityManager.reset(), EndingManager.reset(), NPCRegistry.build_run_pool()
    → PauseUI instanciado como hijo de Main (vive toda la sesión)
    → DaySetupUI instanciado (o reutilizado si ya existe)
      → DaySetupUI.load_day():
          MovieDB.todays_movies(N) → RunState.todays_movies
          Muestra N tarjetas con póster, título, sinopsis, tags
          Botón "★ ABRIR EL CINE" → emite day_setup_done
      → InteractionController._start_day()
          DayPlanDB.build_day(day_i, difficulty) → _customer_list
          manager.start_day(count), RunState.day_max_satisfaction
        ── por cada cliente ──
          CustomerManager spawna Customer.tscn en cola 3D
          customer.arrived → counter_customer_ready
          InteractionController recibe E:
            _needs_dialogue? → DialogueSystem.show_encounter/show_simple
            Después → HUD.show_attend() → jugador elige película
            recommend_movie emitido → _on_recommend_movie
              MatchingSystem.pass_fail → hit/miss
              RunState.earn_money(TICKET_PRICE=10)
              _in_food = true → FoodController.start_food_phase(food_order)
                → PlayerPlacesItems → food_phase_done emitido
              _on_food_done:
                propina (tip de NPC), StockManager.track_sold, food_revenue
                NPCRegistry.record_visit, RunState.npc_seen_today
                tray complete → SAT_FOOD_PERFECT(2) else SAT_FOOD_PARTIAL(1)
                serve_current() → cliente sale
        ── fin de día (timer 1.8s tras último cliente) ──
          RunState.compute_must_appear()
          EventsManager.process_end_of_day() → posible muerte NPC día 3+
          SpecialRoom.end_of_day(satisfaction_fraction)
          EndingManager.check() → posible final prematuro
          StockPurchaseUI.show_purchase(StockManager.end_of_day_summary())
            purchase_confirmed → _show_results_screen()
          EndOfDayUI.show_results() → next_day_requested
          _on_next_day → DaySystem.next_day() → DaySetupUI.load_day()
```

### `Scripts/Main/Main.gd`
- `extends Node3D`
- `_enter_tree`: si `not RunState._coming_from_save` → `RunState.reset_run()`
- `_ready`: consume flag `_coming_from_save`; en partida nueva: `StabilityManager.reset()`, `EndingManager.reset()`, `NPCRegistry.build_run_pool()`; instancia `PauseUI`; gestiona única instancia de `DaySetupUI` (elimina duplicados del grupo `"day_setup_ui"`)
- Preload: `DaySetupUIScript = preload("res://Scripts/UI/DaySetupUI.gd")`

### `Scripts/Game/RunState.gd` — Autoload
Contiene TODO el estado de la run en curso. Es el "modelo" central.

**Constantes de economía:**
- `TICKET_PRICE: int = 10` — entrada fija por cliente
- `SAT_MOVIE_HIT: int = 3` — satisfacción por película acertada
- `SAT_FOOD_PERFECT: int = 2` — bandeja completa
- `SAT_FOOD_PARTIAL: int = 1` — bandeja parcial
- `SAT_MAX_PER_CUSTOMER: int = 5` — máximo por cliente normal

**Variables de run:**
- `todays_movies: Array` — películas del día (Array[Dictionary])
- `player_tags_by_movie: Dictionary` — movie_id → Array[String] (tags marcados por jugador)
- `used_movie_ids: Dictionary` — id → true (no repetir películas entre días)
- `day_index: int = 1`
- `customers_per_day: int = 5`

**Variables de día:**
- `day_hits: int`, `day_misses: int`
- `day_money: int` — dinero del día actual
- `total_money: int` — acumulado de toda la run
- `day_satisfaction: int`, `day_max_satisfaction: int`

**NPCs y narrativa:**
- `ending_type: String` — `"economic"` / `"existential"` / `"grey"` / `""`
- `npc_state: Dictionary` — npc_id → `{visits, satisfaction, active, neutralized_count, dead}`
- `npc_seen_today: Array` — IDs vistos hoy
- `must_appear_tomorrow: Array` — IDs que DEBEN aparecer mañana
- `pending_grief_npc: String` — ID del NPC muerto (pena del día siguiente)
- `session_asked: Dictionary` — npc_id → Array[String] (preguntas de visita actual)
- `run_npc_pool: Array` — IDs sorteados para esta run
- `run_wildcard_roles: Dictionary` — wildcard_id → `"human"` / `"entity"`
- `last_stock_orders: Dictionary` — item → qty (persiste entre días)
- `_coming_from_save: bool = false` — flag one-shot para no hacer reset al cargar

**Métodos públicos:**
- `reset_run()` — limpia todo y llama `reset_day_stats()`
- `reset_day_stats()` — zeroes day_hits/misses/money/satisfaction; limpia npc_seen_today/session_asked
- `earn_money(amount: int)` — incrementa day_money y total_money
- `add_satisfaction(amount: int)` — incrementa day_satisfaction hasta day_max_satisfaction
- `satisfaction_fraction() -> float` — day_satisfaction / day_max_satisfaction
- `day_rating() -> String` — "EXCELENTE" (>=80%), "BUENO" (>=60%), "REGULAR" (>=40%), "MAL DÍA" (<40%), "SIN DATOS"
- `is_used(id: String) -> bool`
- `mark_used(id: String)`
- `compute_must_appear()` — calcula must_appear_tomorrow según satisfaction_fraction: >=0.60 → todos los vistos; >=0.30 → 70% aleatorizados; <0.30 → 50% aleatorizados

---

## Sistemas de NPCs

### `Scripts/Core/NPCRegistry.gd` — Autoload
Carga NPCs desde `Data/NPCs/<id>.json` (un archivo por NPC). El estado per-run vive en `RunState.npc_state`.

**Variable:**
- `_defs: Dictionary` — npc_id → Dictionary con datos del JSON

**Métodos de datos:**
- `get_npc(npc_id) -> Dictionary` — definición completa o `{}`
- `npc_exists(npc_id) -> bool` — existe en JSON + activo + no muerto
- `record_visit(npc_id, satisfaction_delta: int)` — incrementa visits, ajusta satisfaction (0–100)
- `get_npc_state(npc_id) -> Dictionary` — estado en RunState
- `deactivate(npc_id)` — `active = false` en RunState
- `mark_dead(npc_id)` — `active = false`, `dead = true`
- `is_dead(npc_id) -> bool`
- `reset_run()` — limpia RunState.npc_state y re-crea entradas

**Pool de run:**
- `build_run_pool()` — selecciona ~65% de humanos (mínimo 3), ~65% de entidades (mínimo 1), todos los wildcards; asigna `run_wildcard_roles` aleatoriamente; guarda en `RunState.run_npc_pool`
- `is_in_run_pool(npc_id) -> bool`
- `get_effective_type(npc_id) -> String` — `"human"` / `"entity"` (resuelve wildcards)

**Encounters:**
- `get_encounter_index(npc_id) -> int` — `min(visits, encounters.size()-1)`
- `get_current_encounter(npc_id) -> Dictionary` — datos del encuentro actual según visitas

**Utilidad:**
- `static patience_to_profile(patience: int) -> String` — 0 → `"entity"`, 1–4 → `"low"`, 5–7 → `"normal"`, 8+ → `"high"`

**Estado NPC por defecto:**
```
{ "visits": 0, "satisfaction": 50, "active": true, "neutralized_count": 0, "dead": false }
```

### Datos NPC (JSON en `Data/NPCs/<id>.json`)
Un archivo por NPC. Campos estándar:
```json
{
  "id": "carmen",
  "name": "Carmen",
  "npc_type": "human",      // "human" | "entity" | "wildcard"
  "patience": 7,            // 0=entity, 1-4=bajo, 5-7=normal, 8+=alto
  "tip": 3,
  "preferences": {
    "must": ["drama"],
    "must_not": ["horror", "dark"]
  },
  "food_order": { "drink": true, "drink_type": "cola", "popcorn": true, "food": "", ... },
  "encounters": [
    {
      "title": "Primera visita",
      "intro": "Hola, soy Carmen...",
      "questions": [
        { "text": "¿Qué tipo de películas te gustan?", "answer": "..." },
        ...   // 5 preguntas por encuentro
      ],
      "button_text": "Ver cartelera →"  // visita 0: texto introductorio; visita 1+: texto diferente
    }
  ]
}
```
- 10 NPCs totales: 8 humanos, 2 entidades
- NPCs entidad: `patience = 0`, `npc_type = "entity"`

### `Scripts/Core/DayPlanDB.gd` — Autoload
Parsea `Data/DayPlans/day_XX.txt` y construye la lista de clientes del día.

**Método principal:**
- `build_day(day_index: int, difficulty: int) -> Array`
  1. Parsea config del .txt (slots, entity_slots, story_npcs, specials)
  2. Construye lista de NPCs requeridos: story_npcs + must_appear_tomorrow
  3. Rellena con NPCs no vistos (unseen, solo humanos del pool)
  4. Fallback: cualquier NPC disponible del pool
  5. Inserta eventos especiales (warning_entities, familia_alterada, special)
  6. Añade entidades al final (entity_slots)
  7. Procesa pending_grief_npc: modifica primer cliente humano con `is_grieving=true`

**Formato de archivos day_XX.txt:**
```
slots: 4              # N slots de clientes humanos
entity_slots: 1       # N entidades al final
story_npc: carmen     # NPC obligatorio
warning_entities      # aviso especial antes de entidades
familia_alterada      # insertar familia García
special: "Texto"      # mensaje especial
```

**Datos DayPlans actuales:**
- `day_01.txt`: slots:4, entity_slots:0, story_npc:omar
- `day_02.txt`: slots:4, entity_slots:1, story_npc:carmen, warning_entities
- `day_03.txt`: slots:4, entity_slots:1, story_npc:laila, familia_alterada
- `day_04.txt`: slots:5, entity_slots:2 (contenido exacto a confirmar)

**Tipos de clientes generados:**
- `"normal"` — cliente aleatorio sin NPC fijo
- `"npc"` — NPC concreto (tiene npc_id, encounter, tip fijo)
- `"special"` — evento especial (requiere 2 pulsaciones de E)
- `"familia_alterada"` — familia García (must_not: horror/dark/crime; penaliza -15 estabilidad si mal)
- Cualquier cliente puede tener `is_grieving=true` si pending_grief_npc != ""

### `Scripts/Game/DialogueSystem.gd` — NO autoload
Instanciado por InteractionController. Muestra panel de diálogo NPC.

**Señales:**
- `closed` — panel cerrado
- `question_asked` — jugador hizo una pregunta (drena paciencia)

**API:**
- `init(hud: Node)` — referencia al HUD donde se monta el panel
- `show_encounter(npc_id, encounter_data, on_done_callback)` — 5 preguntas, botón contextual
- `show_simple(title, text, buttons_array)` — diálogo simple (familia, grief)
- `is_open() -> bool`
- `hide()`

**Comportamiento:**
- Encuentro: muestra intro del NPC + hasta 5 preguntas clicables + botón de continuar
- Botón contextual: si visits==0 → texto intro; si visits>0 → texto diferente (definido en JSON)
- Cada pregunta que hace el jugador emite `question_asked` → InteractionController drena paciencia

### `Scripts/Game/PatienceSystem.gd` — NO autoload
Instanciado por InteractionController como hijo suyo.

**Señales:**
- `patience_depleted` — se agotó la paciencia
- `patience_warning(fraction)` — aviso de paciencia baja

**Variables:**
- Timers y duración según perfil
- Modos: conversación (normal) / comida (más lento)

**Perfiles de paciencia:**
- `"entity"` — infinita (no se muestra barra)
- `"low"` — agotamiento rápido
- `"normal"` — estándar
- `"high"` — lento (familia García)

**API:**
- `start_for(profile: String)` — inicia timer según perfil
- `stop()`
- `set_mode_food()` — cambia a modo comida (drena más lento)
- `drain_wrong_answer()` — pequeña penalización por pregunta al NPC
- `get_fraction() -> float` — 0.0–1.0
- `is_depleted() -> bool`

**Respeta `get_tree().paused`** — implementado en `_process`.

---

## Sistema de películas

### `Scripts/Game/MovieDB.gd` — class_name MovieDB (NO autoload, llamado estático)

**Catálogo: 20 películas clásicas**
| ID | Título | Runtime | Tags principales |
|----|--------|---------|-----------------|
| `alien` | Alien (1979) | 116 | horror, scifi, thriller, dark, fast |
| `back_to_the_future` | Back to the Future (1985) | 116 | scifi, adventure, comedy, popcorn, fast |
| `blade_runner` | Blade Runner (1982) | 117 | scifi, thriller, crime, mystery, dark, fast |
| `dark_knight` | The Dark Knight (2008) | 152 | action, thriller, crime, drama, dark, slow_burn |
| `die_hard` | Die Hard (1988) | 132 | action, thriller, comedy, popcorn, fast |
| `exorcist` | The Exorcist (1973) | 122 | horror, thriller, drama, dark, mystery, fast |
| `gladiator` | Gladiator (2000) | 155 | action, drama, adventure, dark, slow_burn |
| `godfather` | The Godfather (1972) | 175 | crime, drama, thriller, dark, slow_burn |
| `jaws` | Jaws (1975) | 124 | thriller, horror, adventure, fast |
| `jurassic_park` | Jurassic Park (1993) | 127 | adventure, scifi, thriller, popcorn, fast |
| `matrix` | The Matrix (1999) | 136 | action, scifi, thriller, adventure, fast |
| `monty_python_and_the_holy_grail` | Monty Python (1975) | 92 | comedy, adventure, fantasy, popcorn, fast |
| `pulp_fiction` | Pulp Fiction (1994) | 154 | crime, drama, thriller, dark, slow_burn |
| `raiders_of_the_lost_ark` | Raiders (1981) | 115 | adventure, action, comedy, popcorn, fast |
| `seven` | Se7en (1995) | 127 | thriller, crime, mystery, dark, drama, fast |
| `shining` | The Shining (1980) | 144 | horror, mystery, thriller, dark, drama, slow_burn |
| `silence_of_the_lambs` | Silence of the Lambs (1991) | 118 | thriller, crime, horror, mystery, dark, fast |
| `terminator_two` | Terminator 2 (1991) | 137 | action, scifi, thriller, adventure, popcorn, fast |
| `thing` | The Thing (1982) | 109 | horror, scifi, mystery, dark, thriller, fast |
| `two_thousand_and_one_a_space_odyssey` | 2001 (1968) | 139 | scifi, mystery, drama, dark, fast |

**Nota pace_tag:** `>= 140 min → "slow_burn"`, else `"fast"`. Añadido automáticamente a `true_tags`.

**Géneros principales (5):** Action, Comedy, Drama, Horror, Sci-Fi
- Prioridad: horror > scifi > comedy > action > Drama (fallback)

**Métodos estáticos:**
- `movie(id, poster, runtime_min, tags) -> Dictionary` — construye dict con title_key, syn_key, true_tags, pace, genre
- `draw_unique_for_run(count: int) -> Array` — selecciona películas únicas con diversidad de género (máx 2 por género); garantiza que la última (Sala Especial) comparta género con al menos una anterior; marca todas como usadas en `RunState.used_movie_ids`
- `todays_movies(count: int = 5) -> Array` — alias de `draw_unique_for_run`
- `main_genre_from_tags(tags) -> String`
- `get_main_genre(m: Dictionary) -> String`
- `main_genres() -> Array` — ["Action", "Comedy", "Drama", "Horror", "Sci-Fi"]

**Escalado de películas por día:**
- `DaySystem._movies_for_day(day)`: `clampi(4 + day, 5, 8)` → D1→5, D2→6, D3→7, D4+→8

### `Scripts/Game/TagDB.gd` — Autoload
**14 tags totales:**
- Géneros: `action, drama, comedy, horror, thriller, mystery, scifi, crime, fantasy, adventure`
- Tono: `dark, popcorn`
- Pace: `slow_burn, fast` (NO seleccionables por el jugador en DaySetupUI)

**API:**
- `label(tag_id) -> String` — nombre localizado en español
- `color(tag_id) -> Color` — color fijo por tag para UI consistente
- `is_selectable(tag_id) -> bool` — false para "fast" y "slow_burn"
- `all_tags() -> Array[String]` — los 14 tags

### `Scripts/Game/MatchingSystem.gd` — Autoload (como MatchingSystemAuto)
**Método principal:**
- `pass_fail(customer: Dictionary, movie_tags: Array, threshold: int = 1) -> bool`
  - Cuenta cuántos tags de `customer.must` están en `movie_tags`
  - Devuelve false si algún `customer.must_not` está en `movie_tags`
  - Devuelve true si matches >= threshold
- Threshold dinámico en InteractionController: `max(1, must_count)` (1 must → threshold 1, 2 musts → threshold 2)

### `Scripts/Game/DaySystem.gd` — class_name DaySystem (nodo en escena, NO autoload)
**Variables:**
- `todays_movies: Array` — copia local (también propagada a `RunState.todays_movies`)

**Escalado:**
- `_movies_for_day(day) -> int` — `clampi(4 + day, 5, 8)`
- `_customers_for_day(day) -> int` — `clampi(3 + day * 2, 5, 10)` → D1→5, D2→7, D3→9, ...

**API:**
- `start_new_run()` — `RunState.reset_run()` + `start_day(1)`
- `start_day(day_number)` — actualiza RunState.day_index, customers_per_day, llama `MovieDB.draw_unique_for_run`, propaga a `RunState.todays_movies`
- `next_day()` — `RunState.reset_day_stats()` + `start_day(RunState.day_index + 1)`

---

## Sistemas de NPCs (mecánicas de interacción)

### `Scripts/Game/InteractionController.gd` — class_name InteractionController (~675 líneas)
El orquestador central del gameplay. Conecta CustomerManager, HUD, FoodController, PatienceSystem y DialogueSystem.

**Exports:**
- `customer_manager_path: NodePath`
- `hud_path: NodePath`
- `food_controller_path: NodePath`

**Variables de estado:**
- `_counter_ready: bool`
- `_customer_list: Array`, `_customer_index: int`, `_current_customer: Dictionary`
- `_in_food: bool`
- `_pending_goodbye_key: String`
- `_last_result: String` — "OK" / "FALLO" / ""
- `_last_food_complete: bool`
- `_special_waiting_ack: bool` — esperando segundo E para especial
- `_patience: Node` (PatienceSystem instanciado)
- `_dialogue: Node` (DialogueSystem instanciado)

**Conexiones en `_ready`:**
- `manager.counter_customer_ready` → `_on_counter_ready`
- `manager.counter_customer_changed` → `_on_counter_changed`
- `manager.counter_customer_left` → `_on_counter_left`
- `hud.recommend_movie` → `_on_recommend_movie`
- `food.food_phase_done` → `_on_food_done`
- `_patience.patience_depleted` → `_on_patience_depleted`
- `_patience.patience_warning` → `_on_patience_warning`
- `_dialogue.question_asked` → drena paciencia
- `ContaminationManager.level_changed` → aplica tinte HUD
- `SpecialRoom.neutralized` → actualiza indicador Sala Especial
- `SpecialRoom.capacity_recharged` → actualiza indicador
- Grupo `"day_setup_ui"`: conecta `day_setup_done` → `_start_day`

**Flujo de `_process`:**
1. Actualiza barra paciencia en HUD (oculta para entidades)
2. Si `_in_food`: return
3. Si no `_counter_ready`: return
4. Si `serve_next` (E) presionado:
   - Si panel attend abierto o diálogo abierto: ignorar
   - Si `_special_waiting_ack`: despachar especial y avanzar
   - Si cliente especial: mostrar texto, esperar segundo E
   - Si necesita diálogo (`_needs_dialogue`): `_show_npc_dialogue()`
   - Normal: `_open_movie_panel()`

**`_on_recommend_movie(movie_id)`:**
- Busca película en `RunState.todays_movies`
- Calcula threshold = `max(1, must_count)`
- `MatchingSystem.pass_fail` → hit/miss
- `RunState.earn_money(TICKET_PRICE=10)`
- Si entidad elige película de Sala Especial: `SpecialRoom.try_neutralize(npc_id)`
- Hit: `day_hits++`, `SAT_MOVIE_HIT(3)`, `SoundManager.play_success()`
- Miss: `day_misses++`, `SoundManager.play_fail()`; si `familia_alterada`: `StabilityManager.apply_delta(-15)`, mensaje "La familia García parece… incómoda."
- `_in_food = true`, `_patience.set_mode_food()`, oculta Sala Especial
- Timer 1.6s (react) + 1.4s (food_ask) → `FoodController.start_food_phase(food_order)`

**`_on_food_done`:**
- `_patience.stop()`, oculta barra
- Propina (si no `is_grieving`): `RunState.earn_money(tip)`
- `StockManager.track_sold(food_order)` + `food_revenue`
- Evalúa bandeja via CustomerOrderHUD.is_complete → `SAT_FOOD_PERFECT(2)` o `SAT_FOOD_PARTIAL(1)`
- Reacción flotante 3D sobre cliente: "¡Perfecto! 😊" / "Falta algo... 😕"
- `NPCRegistry.record_visit(npc_id, delta)` — delta: +10 perfecto, -5 parcial, -10 si fallo película
- Timer 0.35s → handoff_tray → timer 0.2s → `serve_current()`, `_advance_customer()`

**`_show_end_of_day`:**
1. `RunState.compute_must_appear()`
2. `EventsManager.process_end_of_day()` (día 3+, posible muerte)
3. `SpecialRoom.end_of_day(satisfaction_fraction)`
4. `EndingManager.check()` — si ya terminó: return
5. Instancia `StockPurchaseUI` → conecta `purchase_confirmed` → `_show_results_screen()`

**`_on_patience_depleted`:**
- `StabilityManager.apply_delta(-5)`
- Muestra mensaje de impaciencia (cargado de `Data/events.json` → `impatience_messages`)
- `serve_current()`, `_advance_customer()`

**`_needs_dialogue(c)` → true si:**
- `c.is_grieving == true`
- `c.type == "familia_alterada"`
- `c.npc_id != ""` (todos los NPCs pasan por diálogo)

**`_show_npc_dialogue()`:**
- familia_alterada: `DialogueSystem.show_simple("La familia García", request_text, [→ _open_movie_panel])`
- grieving: `show_simple(display_name, grief_text, [→ _start_food_directly])`
- NPC normal: `NPCRegistry.get_current_encounter(npc_id)` → `show_encounter(npc_id, encounter, _open_movie_panel)`

**`_update_special_room_hud()`:**
- `hud.update_special_room(SpecialRoom.get_capacity(), SpecialRoom.get_used())`

---

## Sistema de economía y stock

### `Scripts/Core/StabilityManager.gd` — Autoload

**Constantes:**
- `MAX: float = 100.0`

**Variables:**
- `stability: float` — valor actual (0.0–100.0), empieza en 100

**Señales:**
- `stability_changed(value: float)`
- `stability_critical` — emitida cuando estabilidad ≤ 20.0

**API:**
- `reset()` — `stability = 100.0`, emite `stability_changed`
- `apply_delta(delta: float)` — modifica estabilidad, clampea 0–100, emite señales
- `get_fraction() -> float` — stability / MAX

**Fuentes de delta en el código:**
- `SpecialRoom.try_neutralize`: -5
- `_on_patience_depleted`: -5
- `_on_recommend_movie` con familia_alterada: -15
- EndingManager escucha `stability_changed` para verificar condición existencial

### `Scripts/Core/StockManager.gd` — Autoload
Gestiona inventario de comida y bebida.

**Stock comprables (con límite):**
- `"popcorn"`, `"hotdog"`, `"chocolate"`, `"cola"`, `"orange"`, `"rootbeer"`

**Stock ilimitado (toppings):**
- `"ketchup"`, `"mustard"`, `"butter"`, `"caramel"` — siempre disponibles, sin coste

**API:**
- `get_stock() -> Dictionary` — stock actual
- `track_sold(food_order: Dictionary)` — incrementa items vendidos hoy
- `food_revenue(food_order: Dictionary) -> int` — calcula ingresos de la venta
- `end_of_day_summary() -> Dictionary` — devuelve `{item: {sold, wasted, cost_per_unit}}` para StockPurchaseUI
- `purchase_batch(orders: Dictionary) -> int` — aplica pedido, descuenta dinero de `RunState.total_money`, devuelve coste total (-1 si sin fondos)

**Escalado de precios por día** (internos al script, pendiente verificar constantes exactas).

### `Scripts/Game/SpecialRoom.gd` — Autoload
Gestiona neutralizaciones de entidades.

**Constantes:**
- `MAX_CAPACITY: int = 5`
- `BASE_CAPACITY: int = 5`

**Variables:**
- `_capacity: int = BASE_CAPACITY` — hueco disponible hoy
- `_used_today: int = 0`
- `_neutralized_ids: Array[String]` — IDs ya neutralizados

**Señales:**
- `neutralized(entity_id: String)`
- `capacity_full` — sin hueco
- `capacity_recharged(new_cap: int)` — al inicio del día siguiente

**API:**
- `try_neutralize(entity_id) -> bool` — si hay hueco: `_used_today++`, desactiva NPC en NPCRegistry, `StabilityManager.apply_delta(-5)`, emite `neutralized`; si lleno: emite `capacity_full`, return false
- `get_capacity() -> int`
- `get_used() -> int`
- `get_remaining() -> int`
- `end_of_day(sat_fraction: float)` — calcula delta: sat>=0.70 → +1, sat<0.30 → -1, else 0; `_capacity = clampi(_capacity + delta, 1, MAX_CAPACITY)`; emite `capacity_recharged`

**Cómo se activa la Sala Especial:**
- En `_on_recommend_movie`: si `patience_profile == "entity"` y película elegida == última de `RunState.todays_movies` → `SpecialRoom.try_neutralize(npc_id)`

### `Scripts/Game/ContaminationManager.gd` — Autoload
Nivel de contaminación (0.0–1.0) derivado inversamente de la estabilidad.

**Constantes:**
- `GLITCH_CHARS: Array = ["█", "▓", "▒", "░", "╳", "■", "◆"]`

**Variables:**
- `_level: float = 0.0`
- `_rng: RandomNumberGenerator`

**Señales:**
- `level_changed(new_level: float)` — emitida si cambio > 0.005

**Fórmula:**
- `_level = clampf(1.0 - (stability / MAX), 0.0, 1.0)`

**Efectos visuales:**
- `0.00–0.30`: sin efecto
- `0.30–0.60`: `get_display_tags` puede añadir un tag fantasma (horror/dark/crime/mystery) con prob `(level - 0.30) * 1.5`
- `0.60–0.80`: `get_display_tags` puede reemplazar un tag por uno falso con prob `(level - 0.60) * 2.0`; tinte amarillo-verdoso en HUD
- `0.80–1.00`: glitch en títulos (1–2 caracteres reemplazados por GLITCH_CHARS)

**API:**
- `get_level() -> float`
- `get_display_tags(movie_id, real_tags) -> Array` — puede devolver tags alterados según nivel
- `get_display_title(key) -> String` — puede devolver título con glitch (usa TextDB.t internamente)
- `apply_hud_tint(hud: Node)` — modula color de hijos CanvasItem del CanvasLayer
- `clear_hud_tint(hud: Node)` — restaura color blanco

### `Scripts/Game/EventsManager.gd` — Autoload
**Método:**
- `process_end_of_day()`:
  - Solo a partir del `day_index >= 3`
  - `chance = ContaminationManager.get_level() * 0.35` (máx 35%)
  - Si se activa: ordena candidatos por visitas (mayor primero), llama `NPCRegistry.mark_dead(victim)`, `RunState.pending_grief_npc = victim`

**Candidatos a muerte:** NPCs con `visits > 0`, `active == true`, `dead == false`

### `Scripts/Game/EndingManager.gd` — Autoload
**Constantes:**
- `GREY_MONEY_THRESHOLD: int = 2000`
- `GREY_STABILITY_THRESHOLD: float = 20.0`

**Señales:**
- `ending_triggered(type: String)`

**Variables:**
- `_ended: bool = false`

**API:**
- `check()` — verifica condiciones:
  - `day_index >= 2 && total_money <= 0` → `"economic"`
  - `stability <= 0.0` → `"existential"`
  - `total_money >= 2000 && stability < 20.0` → `"grey"`
- `is_ended() -> bool`
- `reset()` — `_ended = false`

**Cuando se activa:**
1. `_ended = true`, `RunState.ending_type = type`
2. `get_tree().paused = true`
3. Emite `ending_triggered`
4. Instancia `EndingScreenUI` con `PROCESS_MODE_ALWAYS`, lo añade a root, llama `show_ending(type)`

---

## Sistema de comida

### `Scripts/Game/Food/FoodController.gd`
Orquesta la fase de comida. Gestiona el estado de la bandeja.

**Señales:**
- `food_phase_done` — cuando la fase de comida termina

**API:**
- `start_food_phase(food_order: Dictionary)` — inicia la fase, configura CustomerOrderHUD, muestra StockHUD
- `get_last_tray_state() -> Dictionary` — estado final de la bandeja
- `handoff_tray_to_customer(customer: Node3D)` — animación de entrega de bandeja

**Food order dict keys:**
- `drink: bool`, `drink_type: String` ("cola"/"orange"/"rootbeer")
- `food: String` (""/"hotdog"/"chocolate")
- `popcorn: bool`
- `ketchup: bool`, `mustard: bool` (solo si hotdog)
- `butter: bool`, `caramel: bool` (solo si popcorn)

### `Scripts/Game/Food/DrinkStation.gd`
Gestiona la estación de bebidas. Actualiza StockHUD y StockManager.

**Señal:**
- Señal interna para indicar bebida añadida a la bandeja

### `Scripts/Game/Food/FoodDB.gd`
Datos estáticos de los items de comida: precios, nombres, descripciones.

### `Scripts/Game/FoodStation.gd`
Nodo de la escena 3D para estaciones de comida. Interacción física del jugador con la comida.

### `Scripts/Game/Tray.gd`
Gestiona el objeto bandeja 3D (contenido visual, posición).

---

## Sistema de guardado

### `Scripts/Game/SaveManager.gd` — Autoload
**Constantes:**
- `SAVE_VERSION: int = 1`
- `MAX_SLOTS: int = 3`
- Rutas: `user://save_slot_1.json` … `user://save_slot_3.json`

**API pública:**
- `slot_path(slot: int) -> String`
- `has_save(slot: int) -> bool`
- `delete_slot(slot: int)` — `DirAccess.remove_absolute`
- `save_slot(slot: int) -> bool` — serializa a JSON indentado, retorna false si fallo I/O
- `load_slot(slot: int) -> bool` — carga JSON, verifica versión, llama `_restore`, activa `RunState._coming_from_save = true`
- `get_slot_info(slot: int) -> Dictionary` — `{slot, day, money, timestamp}` o `{}`

**Datos serializados en `_collect()`:**
```json
{
  "version": 1,
  "timestamp": "2026-02-27T...",
  "run_state": {
    "day_index", "customers_per_day", "total_money",
    "used_movie_ids", "npc_state", "last_stock_orders",
    "must_appear_tomorrow", "pending_grief_npc", "ending_type",
    "run_npc_pool", "run_wildcard_roles"
  },
  "stability": { "value": float },
  "special_room": { "capacity", "used", "neutralized_ids" },
  "contamination": { "level": float },
  "stock": { "items": Dictionary }
}
```

**`_restore(data)`:** Restaura todos los autoloads listados. NO serializa: `day_hits/misses/day_money/day_satisfaction/session_asked/npc_seen_today` (siempre arrancan en 0 al continuar, via `reset_day_stats()`).

**Limitación:** `_coming_from_save` solo evita el reset en `Main._enter_tree`. La inicialización de NPCRegistry se hace llamando `_ensure_npc_state()` para rellenar entradas faltantes.

---

## Sistema de UI

### `Scripts/UI/HUD.gd` — class_name HUD, extends CanvasLayer (~724 líneas)
HUD principal del juego. Construido en código (sin .tscn).

**Paleta Cinema 80s:**
- `C_BG = Color(0.10, 0.04, 0.04, 0.96)`
- `C_GOLD = Color(0.95, 0.76, 0.15)`
- `C_CREAM = Color(0.97, 0.93, 0.80)`
- `C_CREAM_D = Color(0.80, 0.75, 0.60)`
- `C_RED = Color(0.70, 0.06, 0.06)`

**Paneles gestionados:**
- `_prompt_panel/label` — "[E] Atender cliente" (anchor 0.88 vertical, ±220px)
- `_bubble_panel/label` — bocadillo mensaje cliente (anchor 0.48, ±420/90px)
- `_debug_label` — estadísticas debug (solo si ENABLE_DEBUG)
- `_attend_panel` — panel recomendar película (anchor 0.05–0.95, ±540px)
- `_queue_panel/label/dots` — cola de clientes
- `_sat_panel/bar/label` — barra de satisfacción del día
- `_patience_bar_panel/bar/pct_label` — barra de paciencia (bottom-left)
- `_special_room_panel/label/dots` — indicador Sala Especial (bottom-right)

**API pública:**
- `show_prompt(key: String)` — muestra prompt con texto de TextDB; guard `_prompt_visible`
- `hide_prompt()`
- `show_message(text, duration=0.0)` — bocadillo temporal
- `hide_message()` / `hide_bubble()`
- `show_attend(request_line, movies, tags_by_movie)` — panel de películas; crea tarjetas (200px ancho, 280px póster); emite `recommend_movie` por botón "Elegir"
- `hide_attend()`
- `is_attend_open() -> bool`
- `show_debug(text)`
- `update_queue(index, total)`
- `update_satisfaction(current, maximum)`
- `set_patience_bar(visible, fraction)` — oculta si entity o depleted
- `update_special_room(capacity, used)` — muestra indicador bottom-right
- `hide_special_room()`
- `show_money_popup(text)` — popup flotante estilo "+$10 entrada"; apila verticalmente con `_popup_count`

**Señales:**
- `recommend_movie(movie_id: String)` — emitida al pulsar "Elegir" en una tarjeta de película

**Panel attend — tarjetas de película:**
- Ancho fijo `card_w = 200`, alto póster `poster_h = 280`
- Título con font_size dinámico: `clampf(card_w * 0.075, 11, 16)`
- Tags del jugador localizados via `TagDB.label()` (color `C_GOLD`)
- Si `is_sr` (última película): badge "★ SALA ESPECIAL"

### `Scripts/UI/DaySetupUI.gd` — class_name DaySetupUI, extends CanvasLayer (~353 líneas)
Pantalla de inicio de día. Construida en código.

**Señales:**
- `day_setup_done` — conectada por InteractionController para iniciar `_start_day`

**Variables:**
- `movies_per_day: int = 5` (@export)
- Paleta: `C_GOLD`, `C_GOLD_DIM`, `C_CREAM`, `C_CREAM_D`
- `TAGS: Array[String] = ["action", "comedy", "drama", "horror", "scifi"]` — solo 5 tags para chips

**Comportamiento:**
- `_ready`: `add_to_group("day_setup_ui")`, `_build_ui()`, `load_day()`
- `load_day()`: si `RunState.todays_movies` está vacío → `MovieDB.todays_movies(5)`; pre-popula `RunState.player_tags_by_movie` con arrays vacíos; reconstruye tarjetas
- Tarjetas: cada película tiene Card (Panel), póster (TextureRect, min_h=160), badge "★ SALA ESPECIAL" en la última, separador, título (font 15), sinopsis (font 12), chips de tags (5 tags seleccionables)
- Chips: toggle mode; `_toggle_tag` modifica `RunState.player_tags_by_movie[movie_id]`; style diferente selected/unselected (gold border vs dim)
- Botón "★ ABRIR EL CINE" → `_animate_and_done()` → cards fly-out (position -60px, fade 0.45s) → `hide()` → emite `day_setup_done`

### `Scripts/UI/CustomerOrderHUD.gd`
HUD de pedido del cliente durante la fase de comida. Muestra lo que pidió y verifica si la bandeja está completa.

**API:**
- `is_complete(tray_state: Dictionary) -> bool` — compara bandeja actual con el pedido

### `Scripts/UI/StockHUD.gd` — class_name StockHUD, extends Node
HUD de stock visible durante fase de comida (top-left). Sólo para items comprables.

**Constantes:**
- `ORDER: Array[String] = ["popcorn", "hotdog", "chocolate", "cola", "orange", "rootbeer"]`
- `LABELS: Dictionary` — nombres en español de cada item

**API:**
- `show_stock()` / `hide_stock()`
- `set_stock(stock: Dictionary)` — actualiza todas las filas
- `set_item(id, qty)` / `add_item(id, delta)` / `get_item(id) -> int`
- Formato: "x{qty}" (ej: "x4")

**Nodo:** `Main/UI/StockHUD` (referenciado por path desde HUD._force_hide_all)

### `Scripts/UI/StockPurchaseUI.gd` — class_name StockPurchaseUI, extends CanvasLayer
Panel de aprovisionamiento (entre último cliente y EndOfDayUI). Layer=15, PROCESS_MODE_ALWAYS.

**Señales:**
- `purchase_confirmed(cost: int)`

**Items comprables:**
- `PURCHASABLE: Array[String] = ["cola", "orange", "rootbeer", "popcorn", "hotdog", "chocolate"]`

**Comportamiento:**
- `show_purchase(summary)`: carga pedidos previos de `RunState.last_stock_orders` (día 2+) o inicia en 0 (día 1)
- UI: panel 760x680px centrado; columnas PRODUCTO / VENDIDO / DESPERDICIO / MAÑANA (±) / COSTE
- Botón "CONFIRMAR PEDIDO": deshabilitado si coste > total_money
- `_on_confirm()`:
  - `RunState.last_stock_orders = _orders.duplicate()`
  - `StockManager.purchase_batch(_orders)`
  - `EndingManager.check()` — puede activar final económico
  - emite `purchase_confirmed(cost)`

### `Scripts/UI/PauseUI.gd` — class_name PauseUI, extends CanvasLayer
Layer=20, PROCESS_MODE_ALWAYS. Instanciado en Main._ready, vive toda la sesión.

**Señales:**
- `exit_to_menu_requested`

**Comportamiento:**
- ESC toggle via `_unhandled_input`
- `_open()`: refresca stats, `get_tree().paused = true`
- `_on_resume()`: `get_tree().paused = false`
- `_on_menu()`: `SaveManager.save_slot(1)` automáticamente, emite `exit_to_menu_requested`, `get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")`
- `_on_settings()`: TODO (pass vacío)
- Stats mostrados: Día N, Aciertos/Fallos/Clientes, Propinas hoy, Acumulado

### `Scripts/UI/EndOfDayUI.gd` — class_name EndOfDayUI, extends CanvasLayer
Pantalla de resultados. Layer=10. Instanciada dinámicamente.

**Señales:**
- `next_day_requested`

**Rating colors:**
- EXCELENTE → `Color(0.20, 0.95, 0.35)`
- BUENO → `Color(0.60, 0.90, 0.20)`
- REGULAR → `Color(0.95, 0.76, 0.15)`
- MAL DÍA → `Color(1.00, 0.30, 0.30)`
- SIN DATOS → `Color(0.60, 0.60, 0.60)`

**API:**
- `show_results(day, hits, total_customers, money, rating)` — muestra panel, `SoundManager.play_success()`

### `Scripts/UI/EndingScreenUI.gd` — class_name EndingScreenUI, extends CanvasLayer
Layer=50, PROCESS_MODE_ALWAYS. Instanciada por EndingManager.

**Finales definidos:**
- `"economic"`: "CIERRE ECONÓMICO" (rojo), body sobre deudas
- `"existential"`: "BRECHA EXISTENCIAL" (violeta), body sobre entidades
- `"grey"`: "FIN GRIS" (gris), body sobre vacío existencial

**Muestra:** Título, separador, cuerpo narrativo, "Día alcanzado: N", botón "VOLVER A EMPEZAR" → `get_tree().reload_current_scene()`

### `Scripts/UI/UITheme.gd`
Estilos compartidos (cargados via `preload` en scripts de UI).

**Constantes:**
- `C_GOLD = Color(0.95, 0.76, 0.15)`
- `C_CREAM = Color(0.97, 0.93, 0.80)`
- `C_CREAM_D = Color(0.80, 0.75, 0.60)`
- `C_RED = Color(0.70, 0.06, 0.06)`
- `C_GREEN = Color(0.20, 0.85, 0.30)`

**Métodos:**
- `cinema_panel_style() -> StyleBoxFlat` — panel oscuro con borde gold dim, esquinas redondeadas
- `card_style() -> StyleBoxFlat` — variante tarjeta para AttendPanel
- `btn_style(hover: bool) -> StyleBoxFlat` — botón normal/hover gold
- `gold_separator() -> HSeparator` — separador de 1px gold

### `Scripts/Main/MainMenu.gd` — extends Node
Escena `Scenes/MainMenu.tscn`. Menú principal del juego.

**Comportamiento básico:**
- Botones: Nueva partida, Continuar (carga save slot 1), Ajustes, Créditos, Salir
- `change_scene_to_file("res://Scenes/Main.tscn")` para empezar partida nueva

---

## Sistema de clientes 3D

### `Scripts/Customer/CustomerManager.gd` — extends Node3D
Gestiona la cola 3D de clientes.

**Señales:**
- `counter_customer_ready(customer: Node)`
- `counter_customer_left(customer: Node)`
- `counter_customer_changed(customer: Node)`

**Exports:**
- `max_in_queue: int = 5`
- `ground_y: float = 0.0`
- `queue_step: float = 1.15`
- `exit_turn_duration: float = 0.18`
- `exit_pop_height: float = 0.10`
- `exit_pop_up_time: float = 0.06`
- `exit_pop_down_time: float = 0.08`
- `force_despawn_seconds: float = 8.0`

**Nodos referenciados (@onready):**
- `spawn_point`, `counter_point`, `queue_start`, `exit_point` — `../../Points/...`
- `special_back_point`, `exit_point_alt` — opcionales

**Variables:**
- `customer_scene: PackedScene` — `res://Scenes/Customer.tscn`
- `queue: Array[Node]` — cola actual
- `leaving: Dictionary` — clientes saliendo normalmente
- `_special_leaving: Dictionary` — clientes especiales (fase 0=back, 1=exit)
- `_counter_locked: bool` — true mientras el especial recorre SpecialBackPoint
- `_day_total: int`, `_spawned_total: int`

**API:**
- `start_day(total)` — limpia cola, inicia spawn
- `get_counter_customer() -> Node` — `queue[0]` o null
- `serve_current()` — cola[0] sale por exit_point; emit `counter_customer_left`; dequeue; `_ensure_queue_filled`
- `serve_current_special()` — cola[0] va a special_back_point, luego exit_point_alt; bloquea mostrador mientras recorre

**Animación salida:**
- `_play_exit_turn_and_pop`: tween giro (0.18s) + pop vertical (0.06s arriba + 0.08s abajo) del nodo Visual

**`_on_customer_arrived(c)`:**
- Si `leaving`: queue_free
- Si `_special_leaving` phase 0: desbloquear mostrador, ir a exit_alt
- Si `_special_leaving` phase 1: queue_free
- Si primer en cola y mostrador no bloqueado: emite `counter_customer_ready`

### `Scripts/Customer/Customer.gd` — extends Node3D (escena `Customer.tscn`)
Personaje 3D en cola.

**Señal:**
- `arrived(self)` — cuando llega al destino

**Estados:** `IDLE`, `MOVING`, `WAITING`

**API:**
- `go_to(target: Vector3, look_at_cam: bool)` — mueve el personaje al punto indicado

### `Scripts/Customer/CustomerDB.gd` — Autoload
Genera clientes aleatorios y NPCs.

**Variables:**
- `RNG: RandomNumberGenerator`
- `FOODASK: ["cust.foodask.1", "cust.foodask.2", "cust.foodask.3"]`
- `REACT_OK: ["cust.react_ok.1", ..., "cust.react_ok.4"]`
- `REACT_BAD: ["cust.react_bad.1", ..., "cust.react_bad.4"]`
- `GOODBYE: ["cust.goodbye.1", ..., "cust.goodbye.4"]`

**API:**
- `build_day_customers(todays_movies, count, difficulty) -> Array` — clientes aleatorios
- `make_npc_customer_by_id(npc_id, todays_movies, difficulty) -> Dictionary` — crea cliente desde JSON NPC

**`_make_normal(day_tags, difficulty)`:**
- 1 must (siempre), 35% probabilidad de segundo must, 35% must_not
- `_pick_weighted_tag`: tags de tono (`dark`, `popcorn`, `slow_burn`) tienen peso 0.65 vs 1.0

**`_make_food_order(difficulty)`:**
Escalado por dificultad:
- `topping_chance`: 0.50 / 0.675 / 0.85 (D1/D2/D3+)
- `drink_extra`: 0.40 / 0.55 / 0.70
- `pop_combo`: 0.30 / 0.475 / 0.65
- `ketchup_chance`: 0.50 / 0.65 / 0.80
- `mustard_chance`: 0.40 / 0.55 / 0.70
- Roll 0-2: bebida / palomitas / comida; bebida extra si roll != 0; palomitas combo si roll == 2

**`_make_npc_customer(npc_def, ...)`:**
- Preferencias del JSON (must/must_not)
- Si must no están en cartelera de hoy: sustituye por tag del día
- food_order: usa el del JSON si existe, sino `_make_food_order(1)`
- Devuelve dict con: type="npc", npc_id, display_name, patience_profile, tip, request_text, food_order, food_key, ok_key, bad_key, bye_key, must, must_not, exit_lane="main"

---

## Sistema de textos

### `Scripts/Core/TextDB.gd` — Autoload
Textos localizados del juego. Contiene todas las cadenas en ES/EN.

**Variables:**
- `locale: String` — "es" por defecto

**API:**
- `t(key: String) -> String` — devuelve el texto localizado para la clave

**Claves usadas en el juego (muestra):**
- `"ui.counter_ready"` — "[E] Atender cliente"
- `"cust.foodask.1"–".3"` — variantes de petición de comida
- `"cust.react_ok.1"–".4"` — reacciones positivas
- `"cust.react_bad.1"–".4"` — reacciones negativas
- `"cust.goodbye.1"–".4"` — despedidas
- `"movie.<id>.title"` — título de cada película
- `"movie.<id>.syn"` — sinopsis de cada película

### `Scripts/Core/SoundManager.gd` — Autoload
**Métodos:**
- `play_click()` — sonido de clic/botón
- `play_success()` — recomendación acertada / fin de día
- `play_fail()` — recomendación fallida
- `play_cash()` — bandeja completa

### `Scripts/Core/DebugConfig.gd` — Autoload
```gdscript
const ENABLE_DEBUG := true
```
Controla print de debug en todos los sistemas.

---

## Datos (JSON/txt)

### `Data/DayPlans/day_0X.txt`
4 archivos (día 1–4). Ver formato en sección DayPlanDB.

### `Data/NPCs/<id>.json`
10 archivos, uno por NPC. Ver estructura en sección NPCRegistry.
NPCs humanos confirmados: omar, carmen, laila (+ al menos 5 más).
NPCs entidad confirmados: entidad_a (+ al menos 1 más).

**Estructura entidad_a.json (ejemplo de entidad):**
```json
{
  "id": "entidad_a",
  "name": "???",
  "npc_type": "entity",
  "patience": 0,
  "tip": 0,
  "preferences": { "must": [], "must_not": [] },
  "encounters": [...]
}
```

### `Data/events.json`
Mensajes narrativos globales:
```json
{
  "impatience_messages": ["...", "..."],  // mensajes cuando cliente pierde paciencia
  "grief_messages": ["¿Has oído lo de {name}?", ...],  // duelo por NPC muerto
  "warning_entities": ["Hay algo interesado en el cine.", ...]  // aviso entidades
}
```

### `Scripts/Core/Utils.gd` (si existe)
Utilidades generales (contenido mínimo o vacío según lectura).

---

## Puntos frágiles y deuda técnica

### InteractionController.gd (~675 líneas)
- **El nodo más complejo del proyecto.** Combina: loop de clientes, sistema de paciencia, sistema de diálogo, fase de comida, lógica de Sala Especial, eventos narrativos y UI.
- Candidato a split: `Core` (loop base) + `NPCDialogueHandler` + `FoodPhaseHandler`
- Busca `CustomerOrderHUD` por nombre en el árbol (`find_child("*OrderHUD*")`) — frágil si se renombra el nodo
- Busca `DaySystem` por `find_child("DaySystem", true, false)` — fallback manual si no se encuentra (warning + increment manual)
- `_random_impatience_message()` abre y parsea `events.json` en cada llamada (sin caché)

### HUD.gd (~724 líneas)
- Totalmente construido en código — si se necesita ajuste de layout, hay que editar coordenadas en el script
- `_force_hide_all()` busca `StockHUD` por path `"Main/UI/StockHUD"` — acoplado a estructura de escena
- El panel de attend crea tarjetas fijas de 200px de ancho para 5 películas — no escala bien a más películas

### ContaminationManager
- **NO modificar TextDB directamente** — siempre usar `get_display_title()` y `get_display_tags()`
- El tinte HUD modula los `CanvasItem` hijos directos del CanvasLayer — si la estructura del HUD cambia, puede romperse

### PatienceSystem
- **Los timers deben respetar `get_tree().paused`** — implementado en `_process`, no en timers nativos. Si se refactoriza a `Timer`, añadir `process_mode = WHEN_PAUSED` explícito.

### Scripts externos (class_name vs preload)
- `InteractionController`, `FoodController`, `DrinkStation`: usar `preload()` en lugar de `class_name` para evitar conflictos de autoload
- `PatienceSystemScript`, `DialogueSystemScript`, `StockPurchaseUIScript`: todos preloaded dentro de IC

### warning_entities
- **Siempre se inserta al final** de la lista de humanos (antes de entidades) — no en posición configurable, aunque el código usa `special_pos`

### SpecialRoom.end_of_day()
- Se llama desde `InteractionController._show_end_of_day()`, NO desde ningún otro sitio. Si se cambia el flujo de fin de día, verificar que esta llamada no se duplique.

### SaveManager — limitaciones conocidas
- **`contamination._level` se restaura directamente** (propiedad privada `_level`) — si ContaminationManager cambia su API interna, hay que actualizar `_restore()`
- `SpecialRoom._neutralized_ids`, `_capacity`, `_used_today` — también acceso directo a privados
- Versión 1: sin migración de versiones anteriores (solo warning)
- El slot 1 se usa como "autoguardado" desde PauseUI

### PauseUI — "Guardar y Salir"
- `exit_to_menu_requested` emitida pero **Main.gd no la conecta actualmente** (señal pendiente de conectar para guardar antes de salir)
- El guardado (`save_slot(1)`) se hace en `PauseUI._on_menu()` directamente sin confirmación

### MovieDB — sin datos en disco
- Las 20 películas están hardcodeadas en GDScript como `static var MOVIES`
- Los textos (title_key, syn_key) se resuelven en TextDB con claves `"movie.<id>.title"` y `"movie.<id>.syn"`
- `draw_unique_for_run` puede devolver menos de `count` películas en partidas muy largas (fallback relaxa restricción de género)

### DaySetupUI — tags pre-marcados
- `player_tags_by_movie` se inicializa con arrays VACÍOS al cargar el día (el jugador marca desde cero)
- Solo 5 de los 14 tags son seleccionables en DaySetupUI: action, comedy, drama, horror, scifi
- Los tags `fast`/`slow_burn` no son seleccionables pero sí están en `true_tags` de las películas

### NPCRegistry — pool vacío
- Si `run_npc_pool` está vacío (aún no construido), `is_in_run_pool()` devuelve `true` para todos — comportamiento de seguridad que puede causar que aparezcan NPCs fuera del pool en edge cases

### EndingManager — check síncrono
- `EndingManager.check()` se llama en 3 lugares: `_show_end_of_day()`, `StockPurchaseUI._on_confirm()`, y desde la señal `stability_changed`
- Si `total_money` baja de 0 durante un compra de stock (no al inicio del día), el final puede no activarse inmediatamente

### Escenas y rutas críticas
- `res://Scenes/Customer.tscn` — PlayerScene de CustomerManager
- `res://Scenes/Main.tscn` — escena principal del juego
- `res://Scenes/MainMenu.tscn` — menú principal
- Posters: `res://Assets/Posters/<movie_id>.jpg`
- Points 3D: `../../Points/CustomerSpawn`, `CounterPoint`, `QueueStart`, `ExitPoint`, `SpecialBackPoint`, `ExitPointAlt`

### Flujo de satisfacción y must_appear_tomorrow
- `compute_must_appear()` usa `npc_seen_today` (acumulado del día) pero solo incluye NPCs que REALMENTE aparecieron (no todos los del pool)
- Si un NPC muere (EventsManager), puede seguir en `must_appear_tomorrow` — la verificación `_npc_available()` en DayPlanDB lo filtrará al día siguiente

---

## Pendiente / No implementado

| Feature | Estado | Nota |
|---------|--------|------|
| SaveManager (slots múltiples UI) | Script completo | Falta UI de selección de slot en MainMenu |
| PauseUI → conectar `exit_to_menu_requested` en Main.gd | Pendiente | Señal existe pero no conectada |
| Menú principal completo | Escena existe (`MainMenu.tscn`) | Falta 3D fachada cine, integración completa |
| Ajustes (audio, idioma) | Botón en PauseUI con `pass` | No implementado |
| `Scripts/Tools/ProjectReport.gd` | Herramienta de desarrollo | No parte del juego en sí |
| `fantasy` como género | Eliminado del catálogo principal | Solo 5 géneros activos |
| Tags `fast`/`slow_burn` en DaySetupUI | No seleccionables | Solo visibles en `true_tags` internos |
