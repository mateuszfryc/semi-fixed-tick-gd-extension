extends Node2D

const SERVICE_CLASS_NAME := "SemiFixedStepService"
const PAIR_COUNT := 6
const LOG_PREFIX := "[test_shape]"
const STEP_CONFIG := {
    "target_tick_rate": 12,
    "max_steps_per_frame": 8,
    "max_frame_delta": 0.25,
    "time_scale": 1.0,
    "interpolation_enabled": true,
}

var fixed_step: Object
var movers: Array[Dictionary] = []
var sim_time := 0.0
var frame_log_budget := 12
var status_label: Label
var diagnostics_time_accumulator := 0.0

func _ready() -> void:
    _ensure_status_label()
    _set_status("ready() entered")
    print("%s _ready() start" % LOG_PREFIX)
    fixed_step = ClassDB.instantiate(SERVICE_CLASS_NAME)
    if fixed_step == null:
        push_error("Missing GDExtension class: %s" % SERVICE_CLASS_NAME)
        print("%s failed to instantiate %s" % [LOG_PREFIX, SERVICE_CLASS_NAME])
        _set_status("missing class: %s" % SERVICE_CLASS_NAME)
        set_process(false)
        return

    print("%s instantiated %s" % [LOG_PREFIX, SERVICE_CLASS_NAME])
    fixed_step.set_runtime_config(STEP_CONFIG)
    print("%s runtime config applied: %s" % [LOG_PREFIX, STEP_CONFIG])
    _set_status("class instantiated, spawning pairs")
    _spawn_pairs()
    fixed_step.capture_prev_state()
    fixed_step.capture_curr_state()
    print("%s ready with %d movers" % [LOG_PREFIX, movers.size()])
    _set_status("running with %d movers" % movers.size())


func _process(delta: float) -> void:
    if fixed_step == null:
        return

    var result: Dictionary = fixed_step.push_frame_delta(delta)
    if frame_log_budget > 0:
        print("%s frame delta=%.4f result=%s" % [LOG_PREFIX, delta, result])
        _set_status("delta=%.4f steps=%s alpha=%s" % [
            delta,
            result.get("steps_to_run", 0),
            result.get("alpha", 0.0),
        ])
        frame_log_budget -= 1

    var steps_to_run: int = int(result.get("steps_to_run", 0))
    var step_dt: float = float(result.get("step_dt", 0.0))

    if steps_to_run > 0:
        fixed_step.capture_prev_state()
        for _step in range(steps_to_run):
            _simulate_step(step_dt)
        fixed_step.capture_curr_state()

    fixed_step.apply_interpolation(float(result.get("alpha", 0.0)))

    diagnostics_time_accumulator += delta
    if diagnostics_time_accumulator >= 0.5:
        diagnostics_time_accumulator = 0.0
        _log_runtime_snapshot(delta, result)


func _spawn_pairs() -> void:
    var definitions: Array[Dictionary] = [
        {
            "label": "Rect A",
            "position": Vector2(160, 140),
            "amplitude": Vector2(70, 28),
            "speed": 1.1,
            "rotation_span": 0.35,
            "color": Color("ff7a59"),
            "shape": "rect",
            "size": Vector2(78, 42),
        },
        {
            "label": "Rect B",
            "position": Vector2(420, 160),
            "amplitude": Vector2(90, 40),
            "speed": 1.5,
            "rotation_span": 0.55,
            "color": Color("ffd166"),
            "shape": "rect",
            "size": Vector2(58, 58),
        },
        {
            "label": "Circle A",
            "position": Vector2(680, 140),
            "amplitude": Vector2(75, 36),
            "speed": 1.3,
            "rotation_span": 0.2,
            "color": Color("06d6a0"),
            "shape": "circle",
            "radius": 28.0,
        },
        {
            "label": "Circle B",
            "position": Vector2(230, 360),
            "amplitude": Vector2(60, 48),
            "speed": 1.8,
            "rotation_span": 0.4,
            "color": Color("118ab2"),
            "shape": "circle",
            "radius": 34.0,
        },
        {
            "label": "Capsule A",
            "position": Vector2(500, 360),
            "amplitude": Vector2(82, 30),
            "speed": 1.0,
            "rotation_span": 0.65,
            "color": Color("9b5de5"),
            "shape": "capsule",
            "radius": 18.0,
            "height": 88.0,
        },
        {
            "label": "Capsule B",
            "position": Vector2(760, 350),
            "amplitude": Vector2(66, 42),
            "speed": 1.6,
            "rotation_span": 0.5,
            "color": Color("ef476f"),
            "shape": "capsule",
            "radius": 22.0,
            "height": 96.0,
        },
    ]

    for index in range(min(PAIR_COUNT, definitions.size())):
        var definition: Dictionary = definitions[index]
        var pair_root: Node2D = Node2D.new()
        pair_root.name = "%sRoot" % definition["label"]
        pair_root.position = definition["position"]
        add_child(pair_root)

        var logic_anchor: Area2D = Area2D.new()
        logic_anchor.name = "LogicAnchor"
        logic_anchor.position = Vector2.ZERO
        pair_root.add_child(logic_anchor)

        var visual_shell: Node2D = Node2D.new()
        visual_shell.name = "VisualShell"
        visual_shell.position = Vector2.ZERO
        pair_root.add_child(visual_shell)

        _attach_collision_shape(logic_anchor, definition)
        _attach_visual_shape(visual_shell, definition)

        fixed_step.register_interpolated_node(visual_shell, PackedStringArray(["position", "rotation"]))

        movers.append({
            "logic": logic_anchor,
            "visual": visual_shell,
            "origin": pair_root.position,
            "amplitude": definition["amplitude"],
            "speed": float(definition["speed"]),
            "rotation_span": float(definition["rotation_span"]),
            "phase": float(index) * 0.85,
        })
        print("%s spawned %s at %s" % [LOG_PREFIX, definition["label"], pair_root.position])


func _ensure_status_label() -> void:
    if status_label != null:
        return

    status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.position = Vector2(20, 20)
    status_label.text = "test_shape booting..."
    add_child(status_label)


func _set_status(message: String) -> void:
    if status_label != null:
        status_label.text = "test_shape: %s" % message


func _log_runtime_snapshot(delta: float, result: Dictionary) -> void:
    var fps: float = Engine.get_frames_per_second()
    var metrics: Dictionary = fixed_step.get_metrics()
    var status := "fps=%.1f delta=%.4f steps=%s alpha=%s clamp_count=%s nodes=%s fields=%s" % [
        fps,
        delta,
        result.get("steps_to_run", 0),
        result.get("alpha", 0.0),
        metrics.get("clamp_count", 0),
        metrics.get("registered_nodes", 0),
        metrics.get("registered_fields", 0),
    ]
    print("%s %s" % [LOG_PREFIX, status])
    _set_status(status)


func _attach_collision_shape(pair: Area2D, definition: Dictionary) -> void:
    var collision: CollisionShape2D = CollisionShape2D.new()

    match String(definition["shape"]):
        "rect":
            var shape: RectangleShape2D = RectangleShape2D.new()
            shape.size = definition["size"]
            collision.shape = shape
        "circle":
            var shape: CircleShape2D = CircleShape2D.new()
            shape.radius = definition["radius"]
            collision.shape = shape
        "capsule":
            var shape: CapsuleShape2D = CapsuleShape2D.new()
            shape.radius = definition["radius"]
            shape.height = definition["height"]
            collision.shape = shape

    pair.add_child(collision)


func _attach_visual_shape(parent_node: Node2D, definition: Dictionary) -> void:
    var visual: Polygon2D = Polygon2D.new()
    visual.color = Color(definition["color"])
    visual.color.a = 0.45
    visual.polygon = _build_polygon(definition)
    parent_node.add_child(visual)

    var outline: Line2D = Line2D.new()
    outline.width = 3.0
    outline.default_color = Color(definition["color"])
    outline.closed = true
    outline.points = visual.polygon
    parent_node.add_child(outline)


func _build_polygon(definition: Dictionary) -> PackedVector2Array:
    match String(definition["shape"]):
        "rect":
            var size: Vector2 = definition["size"]
            var half: Vector2 = size * 0.5
            return PackedVector2Array([
                Vector2(-half.x, -half.y),
                Vector2(half.x, -half.y),
                Vector2(half.x, half.y),
                Vector2(-half.x, half.y),
            ])
        "circle":
            return _build_circle_polygon(float(definition["radius"]), 24)
        "capsule":
            return _build_capsule_polygon(float(definition["radius"]), float(definition["height"]), 10)
        _:
            return PackedVector2Array()


func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
    var points: PackedVector2Array = PackedVector2Array()
    for index in range(segments):
        var angle: float = TAU * float(index) / float(segments)
        points.append(Vector2.RIGHT.rotated(angle) * radius)
    return points


func _build_capsule_polygon(radius: float, height: float, arc_segments: int) -> PackedVector2Array:
    var points: PackedVector2Array = PackedVector2Array()
    var body_height: float = maxf(height - radius * 2.0, 0.0)
    var top_center: Vector2 = Vector2(0.0, -body_height * 0.5)
    var bottom_center: Vector2 = Vector2(0.0, body_height * 0.5)

    for index in range(arc_segments + 1):
        var angle: float = lerpf(-PI, 0.0, float(index) / float(arc_segments))
        points.append(top_center + Vector2(cos(angle), sin(angle)) * radius)

    for index in range(arc_segments + 1):
        var angle: float = lerpf(0.0, PI, float(index) / float(arc_segments))
        points.append(bottom_center + Vector2(cos(angle), sin(angle)) * radius)

    return points


func _simulate_step(step_dt: float) -> void:
    sim_time += step_dt

    for mover in movers:
        var logic_anchor: Node2D = mover["logic"]
        var visual_shell: Node2D = mover["visual"]
        var origin: Vector2 = mover["origin"]
        var amplitude: Vector2 = mover["amplitude"]
        var speed: float = mover["speed"]
        var rotation_span: float = mover["rotation_span"]
        var phase: float = mover["phase"]

        var t: float = sim_time * speed + phase
        var world_position: Vector2 = origin + Vector2(cos(t) * amplitude.x, sin(t * 1.35) * amplitude.y)
        var simulated_rotation: float = sin(t * 0.8) * rotation_span
        var local_position: Vector2 = world_position - origin

        logic_anchor.position = local_position
        logic_anchor.rotation = simulated_rotation
        visual_shell.position = local_position
        visual_shell.rotation = simulated_rotation
