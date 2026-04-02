#ifndef SFT_STEPPER_H
#define SFT_STEPPER_H

#include "sft_runtime_config.h"

namespace sft {

struct StepResult {
  int steps_to_run = 0;
  double step_dt = 0.0;
  double alpha = 0.0;
  bool was_clamped = false;
};

class Stepper {
private:
  double accumulator = 0.0;

public:
  StepResult push_frame_delta(double p_frame_dt, const RuntimeConfig &p_config);
  void reset();
};

} // namespace sft

#endif // SFT_STEPPER_H
