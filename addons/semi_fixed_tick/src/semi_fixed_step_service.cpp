#include "semi_fixed_step_service.h"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace sft {

void SemiFixedStepService::_bind_methods() {
  ClassDB::bind_method(D_METHOD("set_target_tick_rate", "rate"),
                       &SemiFixedStepService::set_target_tick_rate);
  ClassDB::bind_method(D_METHOD("get_target_tick_rate"),
                       &SemiFixedStepService::get_target_tick_rate);
  ClassDB::bind_method(D_METHOD("set_max_steps_per_frame", "value"),
                       &SemiFixedStepService::set_max_steps_per_frame);
  ClassDB::bind_method(D_METHOD("get_max_steps_per_frame"),
                       &SemiFixedStepService::get_max_steps_per_frame);
  ClassDB::bind_method(D_METHOD("set_max_frame_delta", "value"),
                       &SemiFixedStepService::set_max_frame_delta);
  ClassDB::bind_method(D_METHOD("get_max_frame_delta"),
                       &SemiFixedStepService::get_max_frame_delta);
  ClassDB::bind_method(D_METHOD("set_time_scale", "value"),
                       &SemiFixedStepService::set_time_scale);
  ClassDB::bind_method(D_METHOD("get_time_scale"),
                       &SemiFixedStepService::get_time_scale);
  ClassDB::bind_method(D_METHOD("set_interpolation_enabled", "enabled"),
                       &SemiFixedStepService::set_interpolation_enabled);
  ClassDB::bind_method(D_METHOD("get_interpolation_enabled"),
                       &SemiFixedStepService::get_interpolation_enabled);

  ClassDB::bind_method(D_METHOD("get_fixed_dt"),
                       &SemiFixedStepService::get_fixed_dt);
  ClassDB::bind_method(D_METHOD("push_frame_delta", "frame_dt"),
                       &SemiFixedStepService::push_frame_delta);
  ClassDB::bind_method(D_METHOD("reset_time_state"),
                       &SemiFixedStepService::reset_time_state);

  ClassDB::bind_method(D_METHOD("register_interpolated_node", "node", "fields"),
                       &SemiFixedStepService::register_interpolated_node);
  ClassDB::bind_method(D_METHOD("unregister_interpolated_node", "node"),
                       &SemiFixedStepService::unregister_interpolated_node);
  ClassDB::bind_method(D_METHOD("capture_prev_state"),
                       &SemiFixedStepService::capture_prev_state);
  ClassDB::bind_method(D_METHOD("capture_curr_state"),
                       &SemiFixedStepService::capture_curr_state);
  ClassDB::bind_method(D_METHOD("apply_interpolation", "alpha"),
                       &SemiFixedStepService::apply_interpolation);

  ClassDB::bind_method(D_METHOD("set_runtime_config", "config"),
                       &SemiFixedStepService::set_runtime_config);
  ClassDB::bind_method(D_METHOD("get_metrics"),
                       &SemiFixedStepService::get_metrics);

  ADD_PROPERTY(PropertyInfo(Variant::INT, "target_tick_rate"),
               "set_target_tick_rate", "get_target_tick_rate");
  ADD_PROPERTY(PropertyInfo(Variant::INT, "max_steps_per_frame"),
               "set_max_steps_per_frame", "get_max_steps_per_frame");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_frame_delta"),
               "set_max_frame_delta", "get_max_frame_delta");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "time_scale"), "set_time_scale",
               "get_time_scale");
  ADD_PROPERTY(PropertyInfo(Variant::BOOL, "interpolation_enabled"),
               "set_interpolation_enabled", "get_interpolation_enabled");
  ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "fixed_dt", PROPERTY_HINT_NONE, "",
                            PROPERTY_USAGE_READ_ONLY),
               "", "get_fixed_dt");

  ADD_SIGNAL(MethodInfo("steps_computed",
                        PropertyInfo(Variant::INT, "steps_to_run"),
                        PropertyInfo(Variant::FLOAT, "step_dt"),
                        PropertyInfo(Variant::FLOAT, "alpha")));
  ADD_SIGNAL(MethodInfo("steps_clamped",
                        PropertyInfo(Variant::INT, "frame_steps"),
                        PropertyInfo(Variant::INT, "max_steps")));
  ADD_SIGNAL(MethodInfo("interpolation_applied",
                        PropertyInfo(Variant::FLOAT, "alpha")));
  ADD_SIGNAL(MethodInfo("config_changed",
                        PropertyInfo(Variant::DICTIONARY, "config")));
}

void SemiFixedStepService::set_target_tick_rate(int p_rate) {
  Dictionary d;
  d["target_tick_rate"] = p_rate;
  set_runtime_config(d);
}

int SemiFixedStepService::get_target_tick_rate() const {
  return config.target_tick_rate;
}

void SemiFixedStepService::set_max_steps_per_frame(int p_value) {
  Dictionary d;
  d["max_steps_per_frame"] = p_value;
  set_runtime_config(d);
}

int SemiFixedStepService::get_max_steps_per_frame() const {
  return config.max_steps_per_frame;
}

void SemiFixedStepService::set_max_frame_delta(double p_value) {
  Dictionary d;
  d["max_frame_delta"] = p_value;
  set_runtime_config(d);
}

double SemiFixedStepService::get_max_frame_delta() const {
  return config.max_frame_delta;
}

void SemiFixedStepService::set_time_scale(double p_value) {
  Dictionary d;
  d["time_scale"] = p_value;
  set_runtime_config(d);
}

double SemiFixedStepService::get_time_scale() const {
  return config.time_scale;
}

void SemiFixedStepService::set_interpolation_enabled(bool p_enabled) {
  Dictionary d;
  d["interpolation_enabled"] = p_enabled;
  set_runtime_config(d);
}

bool SemiFixedStepService::get_interpolation_enabled() const {
  return config.interpolation_enabled;
}

double SemiFixedStepService::get_fixed_dt() const { return config.fixed_dt(); }

Dictionary SemiFixedStepService::push_frame_delta(double p_frame_dt) {
  const StepResult result = stepper.push_frame_delta(p_frame_dt, config);

  if (result.was_clamped) {
    clamp_count += 1;
    emit_signal("steps_clamped", result.steps_to_run,
                config.max_steps_per_frame);
  }
  emit_signal("steps_computed", result.steps_to_run, result.step_dt,
              result.alpha);

  Dictionary out;
  out["steps_to_run"] = result.steps_to_run;
  out["step_dt"] = result.step_dt;
  out["alpha"] = result.alpha;
  out["was_clamped"] = result.was_clamped;
  return out;
}

void SemiFixedStepService::reset_time_state() {
  stepper.reset();
  clamp_count = 0;
}

void SemiFixedStepService::register_interpolated_node(
    Node *p_node, const PackedStringArray &p_fields) {
  interpolation_store.register_node(p_node, p_fields);
}

void SemiFixedStepService::unregister_interpolated_node(Node *p_node) {
  interpolation_store.unregister_node(p_node);
}

void SemiFixedStepService::capture_prev_state() {
  if (!config.interpolation_enabled) {
    return;
  }
  interpolation_store.capture_prev_state();
}

void SemiFixedStepService::capture_curr_state() {
  if (!config.interpolation_enabled) {
    return;
  }
  interpolation_store.capture_curr_state();
}

void SemiFixedStepService::apply_interpolation(double p_alpha) {
  if (!config.interpolation_enabled) {
    return;
  }
  interpolation_store.apply_interpolation(p_alpha);
  emit_signal("interpolation_applied", p_alpha);
}

bool SemiFixedStepService::set_runtime_config(const Dictionary &p_config) {
  RuntimeConfig next = config;
  if (!next.apply_dictionary(p_config)) {
    UtilityFunctions::push_error("[SFT] Invalid runtime config.");
    return false;
  }
  config = next;
  emit_signal("config_changed", config.to_dictionary());
  return true;
}

Dictionary SemiFixedStepService::get_metrics() const {
  Dictionary metrics;
  metrics["clamp_count"] = clamp_count;
  metrics["registered_nodes"] = interpolation_store.get_registered_node_count();
  metrics["registered_fields"] =
      interpolation_store.get_registered_field_count();
  return metrics;
}

} // namespace sft
