#ifndef SFT_INTERPOLATION_STORE_H
#define SFT_INTERPOLATION_STORE_H

#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/object_id.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {
class Node;
}

namespace sft {

class InterpolationStore {
private:
  struct FieldState {
    godot::StringName field;
    godot::Variant prev_value;
    godot::Variant curr_value;
  };

  struct NodeState {
    godot::PackedStringArray fields;
    godot::Vector<FieldState> field_states;
  };

  godot::HashMap<godot::ObjectID, NodeState> nodes;

  static bool _is_supported_type(godot::Variant::Type p_type);
  static godot::Variant _interpolate(const godot::Variant &p_prev,
                                     const godot::Variant &p_curr,
                                     double p_alpha);

public:
  void register_node(godot::Node *p_node,
                     const godot::PackedStringArray &p_fields);
  void unregister_node(godot::Node *p_node);

  void capture_prev_state();
  void capture_curr_state();
  void apply_interpolation(double p_alpha);

  int get_registered_node_count() const;
  int get_registered_field_count() const;
};

} // namespace sft

#endif // SFT_INTERPOLATION_STORE_H
