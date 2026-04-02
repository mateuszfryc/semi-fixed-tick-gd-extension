# Quick start

## 1) Dodaj plugin

Skopiuj katalog `addons/semi_fixed_tick` do projektu Godot 4.x i upewnij się, że biblioteka z `.gdextension` jest zbudowana dla Twojej platformy.

> Ten plugin to GDExtension utility i nie wymaga aktywacji przez `Project > Plugins` (brak `EditorPlugin`).

## 2) Utwórz service

```gdscript
var sft := SemiFixedStepService.new()
```

## 3) Ustaw runtime config

```gdscript
sft.set_runtime_config({
    "target_tick_rate": 60,
    "max_steps_per_frame": 8,
    "max_frame_delta": 0.25,
    "time_scale": 1.0,
    "interpolation_enabled": true,
})
```

## 4) Rejestruj pola do interpolacji

```gdscript
sft.register_interpolated_node($Player, PackedStringArray(["global_position", "rotation"]))
```

## 5) Własny loop symulacji

```gdscript
func _process(delta: float) -> void:
    var result := sft.push_frame_delta(delta)

    sft.capture_prev_state()
    for i in range(result.steps_to_run):
        run_gameplay_simulation_tick(result.step_dt)
    sft.capture_curr_state()

    sft.apply_interpolation(result.alpha)
```

Plugin nie zarządza symulacją — dostarcza tylko narzędzia kroku czasu i interpolacji.
