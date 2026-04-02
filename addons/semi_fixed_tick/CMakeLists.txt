cmake_minimum_required(VERSION 3.20)
project(semi_fixed_tick LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Expect GODOT_CPP_DIR to point to a built godot-cpp checkout.
if(NOT DEFINED GODOT_CPP_DIR)
  message(FATAL_ERROR "Set GODOT_CPP_DIR to your godot-cpp path")
endif()

add_library(semi_fixed_tick SHARED
  src/extension_entry.cpp
  src/register_types.cpp
  src/semi_fixed_step_service.cpp
  src/sft_interpolation_store.cpp
  src/sft_runtime_config.cpp
  src/sft_stepper.cpp
)

target_include_directories(semi_fixed_tick PRIVATE
  ${GODOT_CPP_DIR}/include
  ${GODOT_CPP_DIR}/gen/include
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_directories(semi_fixed_tick PRIVATE
  ${GODOT_CPP_DIR}/bin
)

target_link_libraries(semi_fixed_tick PRIVATE godot-cpp)
