#include "sft_interpolation_store.h"

#include <algorithm>
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

namespace sft {

bool InterpolationStore::_is_supported_type(Variant::Type p_type) {
  switch (p_type) {
  case Variant::FLOAT:
  case Variant::VECTOR2:
  case Variant::VECTOR3:
  case Variant::COLOR:
  case Variant::QUATERNION:
  case Variant::TRANSFORM2D:
  case Variant::TRANSFORM3D:
    return true;
  default:
    return false;
  }
}

Variant InterpolationStore::_interpolate(const Variant &p_prev,
                                         const Variant &p_curr,
                                         double p_alpha) {
  const Variant::Type type = p_curr.get_type();
  const real_t alpha = static_cast<real_t>(p_alpha);

  switch (type) {
  case Variant::FLOAT:
    return Math::lerp(static_cast<double>(p_prev), static_cast<double>(p_curr),
                      p_alpha);
  case Variant::VECTOR2:
    return static_cast<Vector2>(p_prev).lerp(static_cast<Vector2>(p_curr),
                                             alpha);
  case Variant::VECTOR3:
    return static_cast<Vector3>(p_prev).lerp(static_cast<Vector3>(p_curr),
                                             alpha);
  case Variant::COLOR:
    return static_cast<Color>(p_prev).lerp(static_cast<Color>(p_curr), alpha);
  case Variant::QUATERNION:
    return static_cast<Quaternion>(p_prev).slerp(
        static_cast<Quaternion>(p_curr), alpha);
  case Variant::TRANSFORM2D: {
    const Transform2D prev_t = static_cast<Transform2D>(p_prev);
    const Transform2D curr_t = static_cast<Transform2D>(p_curr);
    Transform2D out;
    out.set_origin(prev_t.get_origin().lerp(curr_t.get_origin(), alpha));
    out.set_rotation(
        Math::lerp_angle(prev_t.get_rotation(), curr_t.get_rotation(), alpha));
    out.set_scale(prev_t.get_scale().lerp(curr_t.get_scale(), alpha));
    return out;
  }
  case Variant::TRANSFORM3D: {
    const Transform3D prev_t = static_cast<Transform3D>(p_prev);
    const Transform3D curr_t = static_cast<Transform3D>(p_curr);

    Transform3D out;
    out.origin = prev_t.origin.lerp(curr_t.origin, alpha);

    const Quaternion qa(prev_t.basis);
    const Quaternion qb(curr_t.basis);
    out.basis = Basis(qa.slerp(qb, alpha));
    return out;
  }
  default:
    return p_curr;
  }
}

void InterpolationStore::register_node(Node *p_node,
                                       const PackedStringArray &p_fields) {
  ERR_FAIL_NULL(p_node);

  NodeState state;
  state.fields = p_fields;

  for (int i = 0; i < state.fields.size(); i++) {
    const StringName field = state.fields[i];
    const Variant current = p_node->get(field);
    if (!_is_supported_type(current.get_type())) {
      UtilityFunctions::push_warning(
          vformat("[SFT] Unsupported interpolation type for field '%s'",
                  String(field)));
      continue;
    }

    FieldState field_state;
    field_state.field = field;
    field_state.prev_value = current;
    field_state.curr_value = current;
    state.field_states.push_back(field_state);
  }

  nodes.insert(ObjectID(p_node->get_instance_id()), state);
}

void InterpolationStore::unregister_node(Node *p_node) {
  ERR_FAIL_NULL(p_node);
  nodes.erase(ObjectID(p_node->get_instance_id()));
}

void InterpolationStore::capture_prev_state() {
  for (const KeyValue<ObjectID, NodeState> &entry : nodes) {
    Node *node = Object::cast_to<Node>(ObjectDB::get_instance(entry.key));
    if (!node) {
      continue;
    }

    NodeState *state = nodes.getptr(entry.key);
    if (!state) {
      continue;
    }

    FieldState *field_states = state->field_states.ptrw();
    for (int i = 0; i < state->field_states.size(); i++) {
      FieldState &field_state = field_states[i];
      field_state.prev_value = node->get(field_state.field);
    }
  }
}

void InterpolationStore::capture_curr_state() {
  for (const KeyValue<ObjectID, NodeState> &entry : nodes) {
    Node *node = Object::cast_to<Node>(ObjectDB::get_instance(entry.key));
    if (!node) {
      continue;
    }

    NodeState *state = nodes.getptr(entry.key);
    if (!state) {
      continue;
    }

    FieldState *field_states = state->field_states.ptrw();
    for (int i = 0; i < state->field_states.size(); i++) {
      FieldState &field_state = field_states[i];
      field_state.curr_value = node->get(field_state.field);
    }
  }
}

void InterpolationStore::apply_interpolation(double p_alpha) {
  const double alpha = std::clamp(p_alpha, 0.0, 1.0);
  for (const KeyValue<ObjectID, NodeState> &entry : nodes) {
    Node *node = Object::cast_to<Node>(ObjectDB::get_instance(entry.key));
    if (!node) {
      continue;
    }

    for (int i = 0; i < entry.value.field_states.size(); i++) {
      const FieldState &field_state = entry.value.field_states[i];
      node->set(field_state.field, _interpolate(field_state.prev_value,
                                                field_state.curr_value, alpha));
    }
  }
}

int InterpolationStore::get_registered_node_count() const {
  return nodes.size();
}

int InterpolationStore::get_registered_field_count() const {
  int count = 0;
  for (const KeyValue<ObjectID, NodeState> &entry : nodes) {
    count += entry.value.field_states.size();
  }
  return count;
}

} // namespace sft
