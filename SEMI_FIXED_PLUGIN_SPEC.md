# Semi-Fixed Step + interpolacja pól (Godot 4.x) — specyfikacja pluginu produkcyjnego

## 1. Cel pluginu

Plugin **nie uruchamia i nie zarządza symulacją**. Plugin udostępnia narzędzia, które każda symulacja wykorzystuje we własnym kodzie:
- licznik semi-fixed step (ile kroków wykonać w tej klatce),
- współczynnik interpolacji `alpha`,
- rejestr i interpolację oznaczonych pól wizualnych,
- runtime-config dla parametrów kroku czasu.

To daje zespołowi gameplay pełną kontrolę nad logiką symulacji, a plugin dostarcza tylko infrastrukturę czasu/interpolacji.

---

## 2. Zakres funkcjonalny (MVP production-ready)

## 2.1 Semi-fixed step utility

- `fixed_dt` (np. `1/60`) jako krok symulacji,
- akumulator czasu aktualizowany przez `push_frame_delta(frame_dt)`,
- wynik `StepResult`:
  - `steps_to_run` (ile razy wywołać własny tick symulacji),
  - `step_dt` (czas pojedynczego kroku),
  - `alpha` (interpolacja renderowa),
  - `was_clamped` (czy limit kroków został osiągnięty).

## 2.2 Interpolacja wizualna

- plugin trzyma `prev/curr` dla zarejestrowanych pól,
- plugin potrafi policzyć i zastosować interpolację na podstawie `alpha`,
- symulacja sama decyduje kiedy wykonać `capture_prev()`, `capture_curr()`, `apply(alpha)`.

## 2.3 Runtime config

Parametry zmienialne podczas działania:
- `target_tick_rate`,
- `max_steps_per_frame`,
- `max_frame_delta`,
- `time_scale`,
- `interpolation_enabled`.

---

## 3. Architektura pluginu

## 3.1 Komponenty

1. **`SftStepper`**
   - czysta logika semi-fixed,
   - bez wywoływania logiki gry.

2. **`SftInterpolationStore`**
   - mapuje node + pola do snapshotów `prev/curr`,
   - udostępnia funkcje capture/apply.

3. **`SftRuntimeConfig`**
   - waliduje i przechowuje konfigurację.

4. **`SemiFixedStepService` (API Godot, `RefCounted`)**
   - publiczny punkt użycia dla skryptów,
   - żadnego zarządzania lifecycle symulacji.

## 3.2 Zasada odpowiedzialności

- Symulacja (gra) wykonuje własny tick i własne reguły.
- Plugin dostarcza: harmonogram kroków + interpolację pól.

---

## 4. API pluginu (dla twórców Godot)

## 4.1 Klasa główna: `SemiFixedStepService : RefCounted`

### Properties

- `target_tick_rate: int = 60`
- `fixed_dt: float` (read-only)
- `max_steps_per_frame: int = 8`
- `max_frame_delta: float = 0.25`
- `time_scale: float = 1.0`
- `interpolation_enabled: bool = true`

### Metody czasu

- `push_frame_delta(frame_dt: float) -> Dictionary`
  - zwraca `{ steps_to_run, step_dt, alpha, was_clamped }`
- `reset_time_state()`

### Metody interpolacji

- `register_interpolated_node(node: Node, fields: PackedStringArray)`
- `unregister_interpolated_node(node: Node)`
- `capture_prev_state()`
- `capture_curr_state()`
- `apply_interpolation(alpha: float)`

### Metody diagnostyczne

- `get_metrics() -> Dictionary`
- `set_runtime_config(config: Dictionary)`

### Sygnały

- `steps_computed(steps_to_run: int, step_dt: float, alpha: float)`
- `steps_clamped(frame_steps: int, max_steps: int)`
- `interpolation_applied(alpha: float)`
- `config_changed(config: Dictionary)`

---

## 5. Kontrakt integracji z symulacją (kluczowe)

Plugin dostarcza utility; integracja po stronie gry wygląda tak:

1. W `_process(delta)` wywołaj `result = service.push_frame_delta(delta)`.
2. Wykonaj własny tick symulacji `result.steps_to_run` razy.
3. W trakcie ticków symulacji wywołaj `capture_prev_state()` / `capture_curr_state()`.
4. Po tickach wywołaj `apply_interpolation(result.alpha)`.

To gwarantuje, że plugin nie „przejmuje” kontroli nad symulacją.

---

## 6. Oznaczanie pól do interpolacji

## 6.1 Rejestracja

- runtime: `register_interpolated_node(player, ["global_position", "rotation"])`,
- opcjonalnie metadane node: `sft_interpolate_fields`.

## 6.2 Typy MVP

- `float`, `Vector2`, `Vector3`, `Color`,
- `Quaternion` (slerp),
- `Transform2D`/`Transform3D` (kontrolowany blending).

Nieobsługiwane typy:
- pomijane,
- ostrzeżenie rate-limited,
- brak przerwania działania.

---

## 7. Referencyjny algorytm użycia

```text
result = service.push_frame_delta(delta)

for i in range(result.steps_to_run):
    service.capture_prev_state()
    run_my_simulation_tick(result.step_dt)   # kod gry
    service.capture_curr_state()

service.apply_interpolation(result.alpha)
```

Wariant optymalny: `capture_prev_state()` raz na początek batcha kroków, `capture_curr_state()` po ostatnim kroku.

---

## 8. Wydajność i stabilność

- brak alokacji w hot path (prealokacja buforów),
- O(N) względem liczby interpolowanych pól,
- cache dostępu do właściwości (bez kosztownej refleksji na każdej klatce),
- `max_steps_per_frame` jako guard przed spiral of death,
- metryki: liczba clampów, średni koszt apply interpolacji, p95/p99.

MVP: wszystko na głównym wątku (bezpiecznie dla SceneTree).

---

## 9. Minimalny layout pluginu

```text
addons/semi_fixed_tick/
  semi_fixed_tick.gdextension
  plugin.cfg
  src/
    extension_entry.cpp
    register_types.cpp
    sft_stepper.h/.cpp
    sft_runtime_config.h/.cpp
    sft_interpolation_store.h/.cpp
    semi_fixed_step_service.h/.cpp
  docs/
    quick_start.md
```

---

## 10. Przykład użycia (GDScript)

```gdscript
@onready var sft := SemiFixedStepService.new()

func _ready() -> void:
    sft.set_runtime_config({
        "target_tick_rate": 60,
        "max_steps_per_frame": 8,
        "max_frame_delta": 0.25,
        "time_scale": 1.0,
        "interpolation_enabled": true,
    })
    sft.register_interpolated_node($Player, PackedStringArray(["global_position", "rotation"]))

func _process(delta: float) -> void:
    var result := sft.push_frame_delta(delta)

    for i in result.steps_to_run:
        run_gameplay_simulation_tick(result.step_dt)

    sft.apply_interpolation(result.alpha)
```

---

## 11. Definicja production-ready

- stabilny kontrakt API utilities (bez zarządzania symulacją),
- brak crashy w testach obciążeniowych,
- przewidywalny koszt CPU dla `push_frame_delta` i `apply_interpolation`,
- szybki onboarding (quick start + scena demo).
