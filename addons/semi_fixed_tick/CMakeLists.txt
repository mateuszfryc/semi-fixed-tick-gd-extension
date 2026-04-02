cmake_minimum_required(VERSION 3.20)
project(semi_fixed_tick LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Expect GODOT_CPP_DIR to point to a godot-cpp checkout.
if(NOT DEFINED GODOT_CPP_DIR)
  message(FATAL_ERROR "Set GODOT_CPP_DIR to your godot-cpp path")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(SFT_GODOTCPP_TARGET_SUFFIX "template_debug")
  set(SFT_GODOTCPP_CMAKE_SUFFIX "debug")
else()
  set(SFT_GODOTCPP_TARGET_SUFFIX "template_release")
  set(SFT_GODOTCPP_CMAKE_SUFFIX "release")
endif()

set(SFT_GODOTCPP_INCLUDE_DIR ${GODOT_CPP_DIR}/include)
set(SFT_GODOTCPP_GDEXTENSION_DIR ${GODOT_CPP_DIR}/gdextension)
set(SFT_GODOTCPP_GEN_INCLUDE_DIR ${GODOT_CPP_DIR}/gen/include)
set(SFT_GODOTCPP_LIB_DIR ${GODOT_CPP_DIR}/bin)

if(DEFINED GODOT_CPP_BUILD_DIR AND EXISTS "${GODOT_CPP_BUILD_DIR}/gen/include")
  set(SFT_GODOTCPP_GEN_INCLUDE_DIR ${GODOT_CPP_BUILD_DIR}/gen/include)
endif()

if(DEFINED GODOT_CPP_BUILD_DIR AND EXISTS "${GODOT_CPP_BUILD_DIR}/bin")
  set(SFT_GODOTCPP_LIB_DIR ${GODOT_CPP_BUILD_DIR}/bin)
endif()

find_library(SFT_GODOTCPP_LIBRARY
  NAMES
    "godot-cpp.windows.${SFT_GODOTCPP_CMAKE_SUFFIX}.64"
    "godot-cpp.windows.${SFT_GODOTCPP_CMAKE_SUFFIX}.x86_64"
    "godot-cpp.windows.${SFT_GODOTCPP_TARGET_SUFFIX}.x86_64"
    "godot-cpp.linux.${SFT_GODOTCPP_CMAKE_SUFFIX}.64"
    "godot-cpp.linux.${SFT_GODOTCPP_CMAKE_SUFFIX}.x86_64"
    "godot-cpp.linux.${SFT_GODOTCPP_TARGET_SUFFIX}.x86_64"
    "godot-cpp"
  PATHS
    ${SFT_GODOTCPP_LIB_DIR}
  NO_DEFAULT_PATH
)

if(NOT EXISTS "${SFT_GODOTCPP_INCLUDE_DIR}")
  message(FATAL_ERROR "godot-cpp include dir not found: ${SFT_GODOTCPP_INCLUDE_DIR}")
endif()

if(NOT EXISTS "${SFT_GODOTCPP_GDEXTENSION_DIR}")
  message(FATAL_ERROR "godot-cpp gdextension dir not found: ${SFT_GODOTCPP_GDEXTENSION_DIR}")
endif()

if(NOT EXISTS "${SFT_GODOTCPP_GEN_INCLUDE_DIR}")
  message(FATAL_ERROR "godot-cpp generated include dir not found: ${SFT_GODOTCPP_GEN_INCLUDE_DIR}")
endif()

if(NOT SFT_GODOTCPP_LIBRARY)
  message(FATAL_ERROR "godot-cpp library not found in: ${SFT_GODOTCPP_LIB_DIR}")
endif()

set(SFT_PLUGIN_BIN_DIR ${CMAKE_CURRENT_SOURCE_DIR}/bin)

add_library(semi_fixed_tick SHARED
  src/extension_entry.cpp
  src/register_types.cpp
  src/semi_fixed_step_service.cpp
  src/sft_interpolation_store.cpp
  src/sft_runtime_config.cpp
  src/sft_stepper.cpp
)

target_include_directories(semi_fixed_tick PRIVATE
  ${SFT_GODOTCPP_INCLUDE_DIR}
  ${SFT_GODOTCPP_GDEXTENSION_DIR}
  ${SFT_GODOTCPP_GEN_INCLUDE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(semi_fixed_tick PRIVATE ${SFT_GODOTCPP_LIBRARY})

set_target_properties(semi_fixed_tick PROPERTIES
  PREFIX ""
  RUNTIME_OUTPUT_DIRECTORY ${SFT_PLUGIN_BIN_DIR}
  LIBRARY_OUTPUT_DIRECTORY ${SFT_PLUGIN_BIN_DIR}
)

if(WIN32)
  set_target_properties(semi_fixed_tick PROPERTIES
    OUTPUT_NAME_DEBUG "semi_fixed_tick.windows.template_debug.x86_64"
    OUTPUT_NAME_RELEASE "semi_fixed_tick.windows.template_release.x86_64"
    OUTPUT_NAME_RELWITHDEBINFO "semi_fixed_tick.windows.template_release.x86_64"
    OUTPUT_NAME_MINSIZEREL "semi_fixed_tick.windows.template_release.x86_64"
  )
elseif(UNIX AND NOT APPLE)
  set_target_properties(semi_fixed_tick PROPERTIES
    PREFIX "lib"
    OUTPUT_NAME_DEBUG "semi_fixed_tick.linux.template_debug.x86_64"
    OUTPUT_NAME_RELEASE "semi_fixed_tick.linux.template_release.x86_64"
    OUTPUT_NAME_RELWITHDEBINFO "semi_fixed_tick.linux.template_release.x86_64"
    OUTPUT_NAME_MINSIZEREL "semi_fixed_tick.linux.template_release.x86_64"
  )
endif()
