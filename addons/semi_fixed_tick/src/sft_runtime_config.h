#ifndef SFT_RUNTIME_CONFIG_H
#define SFT_RUNTIME_CONFIG_H

#include <godot_cpp/variant/dictionary.hpp>

namespace sft {

struct RuntimeConfig {
  int target_tick_rate = 60;
  int max_steps_per_frame = 8;
  double max_frame_delta = 0.25;
  double time_scale = 1.0;
  bool interpolation_enabled = true;

  double fixed_dt() const;
  bool validate() const;
  bool apply_dictionary(const godot::Dictionary &p_config);
  godot::Dictionary to_dictionary() const;
};

} // namespace sft

#endif // SFT_RUNTIME_CONFIG_H
