#include "register_types.h"

#include "semi_fixed_step_service.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_semi_fixed_tick_module(ModuleInitializationLevel p_level) {
  if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }

  ClassDB::register_class<sft::SemiFixedStepService>();
}

void uninitialize_semi_fixed_tick_module(ModuleInitializationLevel p_level) {
  if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }
}
