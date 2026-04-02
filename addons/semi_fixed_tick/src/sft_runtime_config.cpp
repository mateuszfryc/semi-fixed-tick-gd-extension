#include "sft_runtime_config.h"

#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/string_name.hpp>

using namespace godot;

namespace sft {

namespace {

const Variant KEY_TARGET_TICK_RATE("target_tick_rate");
const Variant KEY_FIXED_DT("fixed_dt");
const Variant KEY_MAX_STEPS_PER_FRAME("max_steps_per_frame");
const Variant KEY_MAX_FRAME_DELTA("max_frame_delta");
const Variant KEY_TIME_SCALE("time_scale");
const Variant KEY_INTERPOLATION_ENABLED("interpolation_enabled");

}

double RuntimeConfig::fixed_dt() const {
  return 1.0 / static_cast<double>(target_tick_rate);
}

bool RuntimeConfig::validate() const {
  return target_tick_rate > 0 && max_steps_per_frame >= 1 &&
         max_frame_delta > 0.0 && time_scale >= 0.0;
}

bool RuntimeConfig::apply_dictionary(const Dictionary &p_config) {
  RuntimeConfig copy = *this;

  if (p_config.has(KEY_TARGET_TICK_RATE)) {
    copy.target_tick_rate = static_cast<int>(
        p_config.get(KEY_TARGET_TICK_RATE, copy.target_tick_rate));
  }
  if (p_config.has(KEY_MAX_STEPS_PER_FRAME)) {
    copy.max_steps_per_frame = static_cast<int>(
        p_config.get(KEY_MAX_STEPS_PER_FRAME, copy.max_steps_per_frame));
  }
  if (p_config.has(KEY_MAX_FRAME_DELTA)) {
    copy.max_frame_delta = static_cast<double>(
        p_config.get(KEY_MAX_FRAME_DELTA, copy.max_frame_delta));
  }
  if (p_config.has(KEY_TIME_SCALE)) {
    copy.time_scale = static_cast<double>(p_config.get(KEY_TIME_SCALE, copy.time_scale));
  }
  if (p_config.has(KEY_INTERPOLATION_ENABLED)) {
    copy.interpolation_enabled = static_cast<bool>(
        p_config.get(KEY_INTERPOLATION_ENABLED, copy.interpolation_enabled));
  }

  if (!copy.validate()) {
    return false;
  }

  *this = copy;
  return true;
}

Dictionary RuntimeConfig::to_dictionary() const {
  Dictionary config;
  config[KEY_TARGET_TICK_RATE] = target_tick_rate;
  config[KEY_FIXED_DT] = fixed_dt();
  config[KEY_MAX_STEPS_PER_FRAME] = max_steps_per_frame;
  config[KEY_MAX_FRAME_DELTA] = max_frame_delta;
  config[KEY_TIME_SCALE] = time_scale;
  config[KEY_INTERPOLATION_ENABLED] = interpolation_enabled;
  return config;
}

} // namespace sft
