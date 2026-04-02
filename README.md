# Stygian

A small open source plugin for Godot 4.x focused on one specific problem: there is no simple, interpolation-friendly `semi-fixed step` utility you can drop into a project without handing over control of your simulation.

This project stays intentionally small. The code is meant to be readable, predictable, and centered on one job: stable simulation stepping with smooth visual interpolation.

## What it does

- computes how many simulation ticks should run in the current frame,
- returns an `alpha` value for interpolation between `prev` and `curr`,
- stores and interpolates selected node properties,
- exposes a runtime config you can tweak without rebuilding your game flow.

This is not a gameplay framework and it does not manage your game loop. It is just timing and interpolation infrastructure.

## Why this exists

You can build a custom semi-fixed loop in Godot 4.x, but once you also want clean visual interpolation, the code tends to become repetitive and annoying to maintain.

This plugin exists to keep that part simple:

- your simulation stays in your hands,
- the API stays small and easy to understand,
- the implementation stays readable without digging through half the engine.

## Quick start

1. Copy `addons/semi_fixed_tick` into your Godot 4.x project.
2. Make sure the native library referenced by `semi_fixed_tick.gdextension` is built for your platform.
3. Create a `SemiFixedStepService`.
4. Register the fields you want interpolated.
5. Use the result of `push_frame_delta(delta)` inside your own simulation loop.

Example:

```gdscript
var sft := SemiFixedStepService.new()

func _ready() -> void:
    sft.set_runtime_config({
        "target_tick_rate": 60,
        "max_steps_per_frame": 8,
        "max_frame_delta": 0.25,
        "time_scale": 1.0,
        "interpolation_enabled": true,
    })

    sft.register_interpolated_node(
        $Player,
        PackedStringArray(["global_position", "rotation"])
    )

func _process(delta: float) -> void:
    var result := sft.push_frame_delta(delta)

    sft.capture_prev_state()
    for i in range(result.steps_to_run):
        run_gameplay_simulation_tick(result.step_dt)
    sft.capture_curr_state()

    sft.apply_interpolation(result.alpha)
```

More details: [addons/semi_fixed_tick/docs/quick_start.md](/c:/Dev/stygian/addons/semi_fixed_tick/docs/quick_start.md)

## API at a glance

Main class: `SemiFixedStepService`

Core methods:

- `push_frame_delta(frame_dt)`
- `reset_time_state()`
- `register_interpolated_node(node, fields)`
- `unregister_interpolated_node(node)`
- `capture_prev_state()`
- `capture_curr_state()`
- `apply_interpolation(alpha)`
- `set_runtime_config(config)`
- `get_metrics()`

## Status

The project is intentionally narrow and currently focused on the MVP:

- semi-fixed stepping,
- interpolation for registered fields,
- simple runtime config,
- clean GDScript-facing API.

If it grows, it should grow carefully. The priority is not feature count, it is clarity and usefulness.

## Building

This plugin is implemented as a C++17 GDExtension.

To build it, you need:

- Godot 4.2+,
- `godot-cpp`,
- CMake 3.20+,
- `GODOT_CPP_DIR` set correctly.

The starting point for the build setup is [addons/semi_fixed_tick/CMakeLists.txt](/c:/Dev/stygian/addons/semi_fixed_tick/CMakeLists.txt).

### Cursor / VS Code

This repo includes `CMakePresets.json` and `.vscode` configs for Cursor / VS Code.

Set these environment variables first:

- `GODOT4_BIN` - path to the Godot 4 editor executable
- `GODOT_PROJECT_PATH` - path to a Godot project where you want to test the plugin

`GODOT_CPP_DIR` is optional in this repo. If it is not set, the build falls back to `C:/godot-cpp`.

Then:

1. Open the repo in Cursor.
2. Run `CMake: Select Configure Preset` and choose `windows-debug` or `windows-release`, or build manually with the included tasks.
3. Use `Terminal > Run Task > CMake: Build preset` to build a selected preset.
4. Press `F5` and choose `Godot: Run project (windows-debug)` to build and launch your test project.

The produced DLL is copied directly into `addons/semi_fixed_tick/bin/`, matching the paths from `semi_fixed_tick.gdextension`.

The configure tasks try to auto-detect a desktop `gcc/g++` toolchain from `PATH` and common Windows locations such as MSYS2 UCRT64. Cross toolchains like `arm-none-eabi` are skipped automatically.

If `godot-cpp` is present but not built yet, the configure step bootstraps it automatically with CMake into `C:/godot-cpp/build/windows-debug` or `C:/godot-cpp/build/windows-release`, then resumes configuring this extension.

The configure step also reads `compatibility_minimum` from `addons/semi_fixed_tick/semi_fixed_tick.gdextension` and automatically switches `godot-cpp` to the best matching local stable tag or branch before building it. If the `godot-cpp` worktree has local changes, the script stops instead of switching refs.

If you want to force GCC/MinGW instead of letting CMake discover a compiler automatically, copy `CMakeUserPresets.json.example` to `CMakeUserPresets.json`, adjust the compiler paths, and then select `windows-debug-gcc` or `windows-release-gcc`.

## Contributing

If you want to help, that would be great. The most useful contributions right now are:

- tests and demo scenes,
- API feedback,
- performance improvements that do not hurt readability,
- edge cases from real Godot 4.x projects.

An issue, a PR, or even a short note saying what felt confusing is genuinely useful. The goal is to make this project practical, not clever.

## License

MIT. See [LICENSE](/c:/Dev/stygian/LICENSE).
