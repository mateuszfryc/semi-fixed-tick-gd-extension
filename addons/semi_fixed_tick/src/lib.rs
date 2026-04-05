use godot::classes::{Node, RefCounted};
use godot::prelude::*;
use std::collections::HashMap;

const KEY_TARGET_TICK_RATE: &str = "target_tick_rate";
const KEY_MAX_STEPS_PER_FRAME: &str = "max_steps_per_frame";
const KEY_MAX_FRAME_DELTA: &str = "max_frame_delta";
const KEY_TIME_SCALE: &str = "time_scale";
const KEY_INTERPOLATION_ENABLED: &str = "interpolation_enabled";
const KEY_FIXED_DT: &str = "fixed_dt";
const KEY_STEPS_TO_RUN: &str = "steps_to_run";
const KEY_STEP_DT: &str = "step_dt";
const KEY_ALPHA: &str = "alpha";
const KEY_WAS_CLAMPED: &str = "was_clamped";
const KEY_CLAMP_COUNT: &str = "clamp_count";
const KEY_REGISTERED_NODES: &str = "registered_nodes";
const KEY_REGISTERED_FIELDS: &str = "registered_fields";

#[derive(Clone)]
struct RuntimeConfig {
    target_tick_rate: i32,
    max_steps_per_frame: i32,
    max_frame_delta: f64,
    time_scale: f64,
    interpolation_enabled: bool,
}

impl Default for RuntimeConfig {
    fn default() -> Self {
        Self {
            target_tick_rate: 60,
            max_steps_per_frame: 8,
            max_frame_delta: 0.25,
            time_scale: 1.0,
            interpolation_enabled: true,
        }
    }
}

impl RuntimeConfig {
    fn fixed_dt(&self) -> f64 {
        1.0 / self.target_tick_rate as f64
    }

    fn validate(&self) -> bool {
        self.target_tick_rate > 0
            && self.max_steps_per_frame >= 1
            && self.max_frame_delta > 0.0
            && self.time_scale >= 0.0
    }

    fn apply_dictionary(&mut self, config: &VarDictionary) -> bool {
        let mut next = self.clone();

        if let Some(value) = config.get(KEY_TARGET_TICK_RATE) {
            let Some(parsed) = variant_to_i32(&value) else {
                return false;
            };
            next.target_tick_rate = parsed;
        }
        if let Some(value) = config.get(KEY_MAX_STEPS_PER_FRAME) {
            let Some(parsed) = variant_to_i32(&value) else {
                return false;
            };
            next.max_steps_per_frame = parsed;
        }
        if let Some(value) = config.get(KEY_MAX_FRAME_DELTA) {
            let Some(parsed) = variant_to_f64(&value) else {
                return false;
            };
            next.max_frame_delta = parsed;
        }
        if let Some(value) = config.get(KEY_TIME_SCALE) {
            let Some(parsed) = variant_to_f64(&value) else {
                return false;
            };
            next.time_scale = parsed;
        }
        if let Some(value) = config.get(KEY_INTERPOLATION_ENABLED) {
            let Some(parsed) = variant_to_bool(&value) else {
                return false;
            };
            next.interpolation_enabled = parsed;
        }

        if !next.validate() {
            return false;
        }

        *self = next;
        true
    }

    fn to_dictionary(&self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        dict.set(KEY_TARGET_TICK_RATE, self.target_tick_rate);
        dict.set(KEY_FIXED_DT, self.fixed_dt());
        dict.set(KEY_MAX_STEPS_PER_FRAME, self.max_steps_per_frame);
        dict.set(KEY_MAX_FRAME_DELTA, self.max_frame_delta);
        dict.set(KEY_TIME_SCALE, self.time_scale);
        dict.set(KEY_INTERPOLATION_ENABLED, self.interpolation_enabled);
        dict
    }
}

#[derive(Default)]
struct StepResult {
    steps_to_run: i32,
    step_dt: f64,
    alpha: f64,
    was_clamped: bool,
}

struct FieldState {
    field: String,
    prev_value: Variant,
    curr_value: Variant,
}

struct NodeState {
    field_states: Vec<FieldState>,
}

#[derive(GodotClass)]
#[class(base=RefCounted)]
struct SemiFixedStepService {
    base: Base<RefCounted>,
    config: RuntimeConfig,
    accumulator: f64,
    clamp_count: i32,
    tracked_nodes: HashMap<InstanceId, NodeState>,
    debug_log_budget: i32,
    debug_frame_counter: i32,
}

#[godot_api]
impl IRefCounted for SemiFixedStepService {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            config: RuntimeConfig::default(),
            accumulator: 0.0,
            clamp_count: 0,
            tracked_nodes: HashMap::new(),
            debug_log_budget: 12,
            debug_frame_counter: 0,
        }
    }
}

#[godot_api]
impl SemiFixedStepService {
    #[signal]
    fn steps_computed(steps_to_run: i32, step_dt: f64, alpha: f64);

    #[signal]
    fn steps_clamped(frame_steps: i32, max_steps: i32);

    #[signal]
    fn interpolation_applied(alpha: f64);

    #[signal]
    fn config_changed(config: VarDictionary);

    #[func]
    fn set_target_tick_rate(&mut self, rate: i32) -> bool {
        let mut config = VarDictionary::new();
        config.set(KEY_TARGET_TICK_RATE, rate);
        self.set_runtime_config(config)
    }

    #[func]
    fn get_target_tick_rate(&self) -> i32 {
        self.config.target_tick_rate
    }

    #[func]
    fn set_max_steps_per_frame(&mut self, value: i32) -> bool {
        let mut config = VarDictionary::new();
        config.set(KEY_MAX_STEPS_PER_FRAME, value);
        self.set_runtime_config(config)
    }

    #[func]
    fn get_max_steps_per_frame(&self) -> i32 {
        self.config.max_steps_per_frame
    }

    #[func]
    fn set_max_frame_delta(&mut self, value: f64) -> bool {
        let mut config = VarDictionary::new();
        config.set(KEY_MAX_FRAME_DELTA, value);
        self.set_runtime_config(config)
    }

    #[func]
    fn get_max_frame_delta(&self) -> f64 {
        self.config.max_frame_delta
    }

    #[func]
    fn set_time_scale(&mut self, value: f64) -> bool {
        let mut config = VarDictionary::new();
        config.set(KEY_TIME_SCALE, value);
        self.set_runtime_config(config)
    }

    #[func]
    fn get_time_scale(&self) -> f64 {
        self.config.time_scale
    }

    #[func]
    fn set_interpolation_enabled(&mut self, enabled: bool) -> bool {
        let mut config = VarDictionary::new();
        config.set(KEY_INTERPOLATION_ENABLED, enabled);
        self.set_runtime_config(config)
    }

    #[func]
    fn get_interpolation_enabled(&self) -> bool {
        self.config.interpolation_enabled
    }

    #[func]
    fn get_fixed_dt(&self) -> f64 {
        self.config.fixed_dt()
    }

    #[func]
    fn push_frame_delta(&mut self, frame_dt: f64) -> VarDictionary {
        let result = self.compute_steps(frame_dt);
        let max_steps_per_frame = self.config.max_steps_per_frame;
        self.debug_frame_counter += 1;

        if result.was_clamped {
            self.clamp_count += 1;
            godot_warn!(
                "[SFT Rust] clamp frame={} steps={} max_steps={} accumulator={:.5}",
                self.debug_frame_counter,
                result.steps_to_run,
                max_steps_per_frame,
                self.accumulator
            );
            self.signals()
                .steps_clamped()
                .emit(result.steps_to_run, max_steps_per_frame);
        }

        if self.debug_log_budget > 0 || self.debug_frame_counter % 120 == 0 {
            godot_print!(
                "[SFT Rust] frame={} frame_dt={:.5} step_dt={:.5} steps={} alpha={:.4} tracked_nodes={} tracked_fields={}",
                self.debug_frame_counter,
                frame_dt,
                result.step_dt,
                result.steps_to_run,
                result.alpha,
                self.tracked_nodes.len(),
                self.tracked_nodes
                    .values()
                    .map(|state| state.field_states.len() as i32)
                    .sum::<i32>()
            );
            if self.debug_log_budget > 0 {
                self.debug_log_budget -= 1;
            }
        }

        self.signals()
            .steps_computed()
            .emit(result.steps_to_run, result.step_dt, result.alpha);

        let mut out = VarDictionary::new();
        out.set(KEY_STEPS_TO_RUN, result.steps_to_run);
        out.set(KEY_STEP_DT, result.step_dt);
        out.set(KEY_ALPHA, result.alpha);
        out.set(KEY_WAS_CLAMPED, result.was_clamped);
        out
    }

    #[func]
    fn reset_time_state(&mut self) {
        self.accumulator = 0.0;
        self.clamp_count = 0;
    }

    #[func]
    fn register_interpolated_node(&mut self, node: Gd<Node>, fields: PackedStringArray) {
        let node_id = node.instance_id();
        let mut state = NodeState {
            field_states: Vec::new(),
        };

        for field_name in fields.as_slice() {
            let field = field_name.to_string();
            let current = node.get(&field);
            if !is_supported_type(&current) {
                godot_warn!(
                    "[SFT Rust] Unsupported interpolation type for field '{}'",
                    field_name
                );
                continue;
            }

            state.field_states.push(FieldState {
                field,
                prev_value: current.clone(),
                curr_value: current,
            });
        }

        self.tracked_nodes.insert(node_id, state);
        godot_print!(
            "[SFT Rust] register_interpolated_node id={:?} requested_fields={} tracked_nodes={}",
            node_id,
            fields.len(),
            self.tracked_nodes.len()
        );
    }

    #[func]
    fn unregister_interpolated_node(&mut self, node: Gd<Node>) {
        self.tracked_nodes.remove(&node.instance_id());
    }

    #[func]
    fn capture_prev_state(&mut self) {
        if !self.config.interpolation_enabled {
            return;
        }

        for (instance_id, state) in self.tracked_nodes.iter_mut() {
            let Ok(node) = Gd::<Node>::try_from_instance_id(*instance_id) else {
                continue;
            };

            for field_state in &mut state.field_states {
                field_state.prev_value = node.get(&field_state.field);
            }
        }
    }

    #[func]
    fn capture_curr_state(&mut self) {
        if !self.config.interpolation_enabled {
            return;
        }

        for (instance_id, state) in self.tracked_nodes.iter_mut() {
            let Ok(node) = Gd::<Node>::try_from_instance_id(*instance_id) else {
                continue;
            };

            for field_state in &mut state.field_states {
                field_state.curr_value = node.get(&field_state.field);
            }
        }
    }

    #[func]
    fn apply_interpolation(&mut self, alpha: f64) {
        if !self.config.interpolation_enabled {
            return;
        }

        let alpha = alpha.clamp(0.0, 1.0);
        for (instance_id, state) in self.tracked_nodes.iter() {
            let Ok(mut node) = Gd::<Node>::try_from_instance_id(*instance_id) else {
                continue;
            };

            for field_state in &state.field_states {
                let value = interpolate_variant(&field_state.prev_value, &field_state.curr_value, alpha);
                node.set(&field_state.field, &value);
            }
        }

        self.signals().interpolation_applied().emit(alpha);
    }

    #[func]
    fn set_runtime_config(&mut self, config: VarDictionary) -> bool {
        let mut next = self.config.clone();
        if !next.apply_dictionary(&config) {
            godot_error!("[SFT Rust] Invalid runtime config.");
            return false;
        }

        self.config = next;
        let config_snapshot = self.config.to_dictionary();
        godot_print!(
            "[SFT Rust] config target_tick_rate={} fixed_dt={:.5} max_steps_per_frame={} max_frame_delta={:.3} time_scale={:.3} interpolation_enabled={}",
            self.config.target_tick_rate,
            self.config.fixed_dt(),
            self.config.max_steps_per_frame,
            self.config.max_frame_delta,
            self.config.time_scale,
            self.config.interpolation_enabled
        );
        self.signals().config_changed().emit(&config_snapshot);
        true
    }

    #[func]
    fn get_metrics(&self) -> VarDictionary {
        let mut metrics = VarDictionary::new();
        metrics.set(KEY_CLAMP_COUNT, self.clamp_count);
        metrics.set(KEY_REGISTERED_NODES, self.tracked_nodes.len() as i32);
        metrics.set(
            KEY_REGISTERED_FIELDS,
            self.tracked_nodes
                .values()
                .map(|state| state.field_states.len() as i32)
                .sum::<i32>(),
        );
        metrics
    }
}

impl SemiFixedStepService {
    fn compute_steps(&mut self, frame_dt: f64) -> StepResult {
        let mut result = StepResult::default();
        result.step_dt = self.config.fixed_dt();

        let scaled_dt = frame_dt * self.config.time_scale;
        let clamped_dt = scaled_dt.clamp(0.0, self.config.max_frame_delta);

        self.accumulator += clamped_dt;
        while self.accumulator >= result.step_dt
            && result.steps_to_run < self.config.max_steps_per_frame
        {
            self.accumulator -= result.step_dt;
            result.steps_to_run += 1;
        }

        if self.accumulator >= result.step_dt {
            result.was_clamped = true;
            self.accumulator = self.accumulator.min(result.step_dt);
        }

        result.alpha = if result.step_dt > 0.0 {
            (self.accumulator / result.step_dt).clamp(0.0, 1.0)
        } else {
            0.0
        };

        result
    }
}

fn variant_to_i32(value: &Variant) -> Option<i32> {
    value
        .try_to::<i32>()
        .ok()
        .or_else(|| value.try_to::<i64>().ok().map(|v| v as i32))
}

fn variant_to_f64(value: &Variant) -> Option<f64> {
    value
        .try_to::<f64>()
        .ok()
        .or_else(|| value.try_to::<f32>().ok().map(|v| v as f64))
}

fn variant_to_bool(value: &Variant) -> Option<bool> {
    value.try_to::<bool>().ok()
}

fn is_supported_type(value: &Variant) -> bool {
    matches!(
        value.get_type(),
        VariantType::FLOAT
            | VariantType::VECTOR2
            | VariantType::VECTOR3
            | VariantType::COLOR
            | VariantType::QUATERNION
            | VariantType::TRANSFORM2D
            | VariantType::TRANSFORM3D
    )
}

fn interpolate_variant(prev: &Variant, curr: &Variant, alpha: f64) -> Variant {
    let alpha_f32 = alpha as f32;

    match curr.get_type() {
        VariantType::FLOAT => {
            let prev_value = prev.to::<f64>();
            let curr_value = curr.to::<f64>();
            Variant::from(prev_value + (curr_value - prev_value) * alpha)
        }
        VariantType::VECTOR2 => {
            let prev_value = prev.to::<Vector2>();
            let curr_value = curr.to::<Vector2>();
            Variant::from(prev_value.lerp(curr_value, alpha_f32))
        }
        VariantType::VECTOR3 => {
            let prev_value = prev.to::<Vector3>();
            let curr_value = curr.to::<Vector3>();
            Variant::from(prev_value.lerp(curr_value, alpha_f32))
        }
        VariantType::COLOR => {
            let prev_value = prev.to::<Color>();
            let curr_value = curr.to::<Color>();
            Variant::from(prev_value.lerp(curr_value, alpha))
        }
        VariantType::QUATERNION => {
            let prev_value = prev.to::<Quaternion>();
            let curr_value = curr.to::<Quaternion>();
            Variant::from(prev_value.slerp(curr_value, alpha_f32))
        }
        VariantType::TRANSFORM2D => {
            let prev_value = prev.to::<Transform2D>();
            let curr_value = curr.to::<Transform2D>();
            Variant::from(prev_value.interpolate_with(&curr_value, alpha_f32))
        }
        VariantType::TRANSFORM3D => {
            let prev_value = prev.to::<Transform3D>();
            let curr_value = curr.to::<Transform3D>();
            Variant::from(prev_value.interpolate_with(&curr_value, alpha_f32))
        }
        _ => curr.clone(),
    }
}

struct SemiFixedTickRustExtension;

#[gdextension]
unsafe impl ExtensionLibrary for SemiFixedTickRustExtension {}
