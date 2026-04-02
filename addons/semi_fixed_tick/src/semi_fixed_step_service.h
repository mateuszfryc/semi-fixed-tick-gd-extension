#ifndef SEMI_FIXED_STEP_SERVICE_H
#define SEMI_FIXED_STEP_SERVICE_H

#include "sft_interpolation_store.h"
#include "sft_runtime_config.h"
#include "sft_stepper.h"

#include <godot_cpp/classes/ref_counted.hpp>

namespace sft {

class SemiFixedStepService : public godot::RefCounted {
  GDCLASS(SemiFixedStepService, godot::RefCounted)

private:
  RuntimeConfig config;
  Stepper stepper;
  InterpolationStore interpolation_store;

  int clamp_count = 0;

protected:
  static void _bind_methods();

public:
  SemiFixedStepService() = default;

  void set_target_tick_rate(int p_rate);
  int get_target_tick_rate() const;

  void set_max_steps_per_frame(int p_value);
  int get_max_steps_per_frame() const;

  void set_max_frame_delta(double p_value);
  double get_max_frame_delta() const;

  void set_time_scale(double p_value);
  double get_time_scale() const;

  void set_interpolation_enabled(bool p_enabled);
  bool get_interpolation_enabled() const;

  double get_fixed_dt() const;

  godot::Dictionary push_frame_delta(double p_frame_dt);
  void reset_time_state();

  void register_interpolated_node(godot::Node *p_node,
                                  const godot::PackedStringArray &p_fields);
  void unregister_interpolated_node(godot::Node *p_node);
  void capture_prev_state();
  void capture_curr_state();
  void apply_interpolation(double p_alpha);

  bool set_runtime_config(const godot::Dictionary &p_config);
  godot::Dictionary get_metrics() const;
};

} // namespace sft

#endif // SEMI_FIXED_STEP_SERVICE_H
