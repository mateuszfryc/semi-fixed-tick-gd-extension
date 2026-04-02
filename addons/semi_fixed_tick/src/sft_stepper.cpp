#include "sft_stepper.h"

#include <algorithm>

namespace sft {

StepResult Stepper::push_frame_delta(double p_frame_dt,
                                     const RuntimeConfig &p_config) {
  StepResult result;
  result.step_dt = p_config.fixed_dt();

  const double scaled_dt = p_frame_dt * p_config.time_scale;
  const double frame_dt = std::clamp(scaled_dt, 0.0, p_config.max_frame_delta);

  accumulator += frame_dt;
  while (accumulator >= result.step_dt &&
         result.steps_to_run < p_config.max_steps_per_frame) {
    accumulator -= result.step_dt;
    result.steps_to_run += 1;
  }

  if (accumulator >= result.step_dt) {
    result.was_clamped = true;
    accumulator = std::min(accumulator, result.step_dt);
  }

  result.alpha = (result.step_dt > 0.0) ? (accumulator / result.step_dt) : 0.0;
  result.alpha = std::clamp(result.alpha, 0.0, 1.0);
  return result;
}

void Stepper::reset() { accumulator = 0.0; }

} // namespace sft
