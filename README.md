# iSFS - Interpolated Semi-Fixed Step Extension for Godot 4.x

A small GDExtension for Godot 4.x focused on one job: semi-fixed simulation stepping with smooth visual interpolation.

The project stays intentionally narrow. It does not try to own your game loop or become a framework. It gives you timing and interpolation primitives that you can plug into your own simulation code.

## What it does

- computes how many simulation ticks should run in the current frame
- returns an `alpha` value for interpolation between `prev` and `curr`
- stores and interpolates selected node properties
- exposes runtime config you can tweak from GDScript

## Why this exists

Building a semi-fixed loop in Godot is manageable. Building one that also keeps visuals smooth and reusable across projects gets repetitive fast.

This plugin exists to keep that part small and explicit:

- your simulation stays in your hands
- the public API stays compact
- the implementation stays readable

## Why Rust

This repository originally started with a C++ GDExtension implementation.

We moved the plugin to Rust for practical workflow reasons, not because the API changed:

- on Windows, the C++ workflow kept colliding with DLL locking during iteration, especially when Godot had a library loaded and the next build tried to overwrite it
- the Rust integration gave us a much smoother edit-build-sync loop for local development
- the Rust code is easier to keep memory-safe while still exposing the same small Godot-facing API
- keeping one implementation is simpler than maintaining a C++ and Rust version side by side

So the current direction of the project is one addon, one public API, implemented in Rust.

## Runtime package

If you only want to use the plugin in a Godot game, you do not need the whole repository.

The minimal runtime package is:

```text
addons/semi_fixed_tick/
  semi_fixed_tick.gdextension
  bin/
    ...
```

The `.gdextension` file points to `res://addons/semi_fixed_tick/...`, so keeping that path in the consuming project is the simplest option.

## Using it

1. Copy `addons/semi_fixed_tick/` into your Godot 4.x project.
2. Make sure the DLL referenced by `semi_fixed_tick.gdextension` matches your platform and build profile.
3. Create a `SemiFixedStepService`.
4. Register the fields you want interpolated.
5. Run your simulation ticks from `push_frame_delta(delta)` and apply interpolation with the returned `alpha`.

Example:

```gdscript
var fixed_step := SemiFixedStepService.new()

func _ready() -> void:
    fixed_step.set_runtime_config({
        "target_tick_rate": 60,
        "max_steps_per_frame": 8,
        "max_frame_delta": 0.25,
        "time_scale": 1.0,
        "interpolation_enabled": true,
    })

    fixed_step.register_interpolated_node(
        $PlayerVisual,
        PackedStringArray(["position", "rotation"])
    )

func _process(delta: float) -> void:
    var result := fixed_step.push_frame_delta(delta)

    if result.steps_to_run > 0:
        fixed_step.capture_prev_state()
        for _i in range(result.steps_to_run):
            run_gameplay_simulation_tick(result.step_dt)
        fixed_step.capture_curr_state()

    fixed_step.apply_interpolation(result.alpha)
```

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

## Building

This repository is the development repo for the extension itself.

The current build flow is Rust-only and uses Cargo.

Requirements:

- Godot 4.5+
- Rust toolchain with Cargo

### Cursor / VS Code

The workspace includes Rust-focused `tasks.json` and `launch.json` entries.

Useful tasks:

1. `Cargo: Build semi_fixed_tick debug`
2. `Cargo: Sync semi_fixed_tick debug`
3. `Cargo: Build semi_fixed_tick release`
4. `Cargo: Sync semi_fixed_tick release`

Useful debug menu entries:

- `Rust Cargo debug`
- `Rust Cargo Editor debug`
- `Rust Cargo release`
- `Rust Cargo Editor release`

`F5` can be used from the debug menu to run the matching build or build-and-open flow.

The sync step copies the Cargo-built DLL into `addons/semi_fixed_tick/bin/` under a versioned filename and updates `semi_fixed_tick.gdextension` to point at the newest copy. That versioned copy is the current workaround for Windows DLL locking during iteration.

If you keep a local `.env` file in the repo root, `scripts/run-godot-project.ps1` can use `GODOT4_BIN` from there to launch the editor.

## Demo scene

This repository also contains a local Godot project and a small visual test scene:

- [test_shape.tscn](./test_shape.tscn)
- [test_shape.gd](./test_shape.gd)

It creates several moving shape pairs and uses the extension to interpolate their visuals between simulation ticks.

Use `F6` in Godot to run the currently opened scene. `F5` runs the project main scene instead.

## Contributing

Contributions are welcome, especially around:

- tests and demo scenes
- API feedback
- performance improvements that keep the code readable
- edge cases from real Godot 4.x projects

Bug reports, feature requests, and design discussion should go through Issues. Code changes should go through Pull Requests.

## License

MIT. See [LICENSE](./LICENSE).
