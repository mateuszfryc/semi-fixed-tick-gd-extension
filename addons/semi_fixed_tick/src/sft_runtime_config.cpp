#include "sft_runtime_config.h"

#include <godot_cpp/variant/string_name.hpp>

using namespace godot;

namespace sft {

double RuntimeConfig::fixed_dt() const {
  return 1.0 / static_cast<double>(target_tick_rate);
}

bool RuntimeConfig::validate() const {
  return target_tick_rate > 0 && max_steps_per_frame >= 1 &&
         max_frame_delta > 0.0 && time_scale >= 0.0;
}

bool RuntimeConfig::apply_dictionary(const Dictionary &p_config) {
  RuntimeConfig copy = *this;

  if (p_config.has("target_tick_rate")) {
    copy.target_tick_rate = static_cast<int>(p_config.get("target_tick_rate"));
  }
  if (p_config.has("max_steps_per_frame")) {
    copy.max_steps_per_frame =
        static_cast<int>(p_config.get("max_steps_per_frame"));
  }
  if (p_config.has("max_frame_delta")) {
    copy.max_frame_delta = static_cast<double>(p_config.get("max_frame_delta"));
  }
  if (p_config.has("time_scale")) {
    copy.time_scale = static_cast<double>(p_config.get("time_scale"));
  }
  if (p_config.has("interpolation_enabled")) {
    copy.interpolation_enabled =
        static_cast<bool>(p_config.get("interpolation_enabled"));
  }

  if (!copy.validate()) {
    return false;
  }

  *this = copy;
  return true;
}

Dictionary RuntimeConfig::to_dictionary() const {
  Dictionary config;
  config["target_tick_rate"] = target_tick_rate;
  config["fixed_dt"] = fixed_dt();
  config["max_steps_per_frame"] = max_steps_per_frame;
  config["max_frame_delta"] = max_frame_delta;
  config["time_scale"] = time_scale;
  config["interpolation_enabled"] = interpolation_enabled;
  return config;
}

} // namespace sft
