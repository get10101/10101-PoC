#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef int64_t DartPort;

typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);

typedef struct wire_uint_8_list {
  uint8_t *ptr;
  int32_t len;
} wire_uint_8_list;

typedef struct wire_list_tree_node {
  struct wire_TreeNode *ptr;
  int32_t len;
} wire_list_tree_node;

typedef struct wire_TreeNode {
  struct wire_uint_8_list *name;
  struct wire_list_tree_node *children;
} wire_TreeNode;

typedef struct wire_Size {
  int32_t width;
  int32_t height;
} wire_Size;

typedef struct wire_list_size {
  struct wire_Size *ptr;
  int32_t len;
} wire_list_size;

typedef struct WireSyncReturnStruct {
  uint8_t *ptr;
  int32_t len;
  bool success;
} WireSyncReturnStruct;

void store_dart_post_cobject(DartPostCObjectFnType ptr);

void wire_run(int64_t port_);

void wire_passing_complex_structs(int64_t port_, struct wire_TreeNode *root);

void wire_returning_structs_with_boxed_fields(int64_t port_);

void wire_off_topic_memory_test_input_array(int64_t port_, struct wire_uint_8_list *input);

void wire_off_topic_memory_test_output_zero_copy_buffer(int64_t port_, int32_t len);

void wire_off_topic_memory_test_output_vec_u8(int64_t port_, int32_t len);

void wire_off_topic_memory_test_input_vec_of_object(int64_t port_, struct wire_list_size *input);

void wire_off_topic_memory_test_output_vec_of_object(int64_t port_, int32_t len);

void wire_off_topic_memory_test_input_complex_struct(int64_t port_, struct wire_TreeNode *input);

void wire_off_topic_memory_test_output_complex_struct(int64_t port_, int32_t len);

void wire_off_topic_deliberately_return_error(int64_t port_);

void wire_off_topic_deliberately_panic(int64_t port_);

struct wire_TreeNode *new_box_autoadd_tree_node_0(void);

struct wire_list_size *new_list_size_0(int32_t len);

struct wire_list_tree_node *new_list_tree_node_0(int32_t len);

struct wire_uint_8_list *new_uint_8_list_0(int32_t len);

void free_WireSyncReturnStruct(struct WireSyncReturnStruct val);

static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) wire_run);
    dummy_var ^= ((int64_t) (void*) wire_passing_complex_structs);
    dummy_var ^= ((int64_t) (void*) wire_returning_structs_with_boxed_fields);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_input_array);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_output_zero_copy_buffer);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_output_vec_u8);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_input_vec_of_object);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_output_vec_of_object);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_input_complex_struct);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_memory_test_output_complex_struct);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_deliberately_return_error);
    dummy_var ^= ((int64_t) (void*) wire_off_topic_deliberately_panic);
    dummy_var ^= ((int64_t) (void*) new_box_autoadd_tree_node_0);
    dummy_var ^= ((int64_t) (void*) new_list_size_0);
    dummy_var ^= ((int64_t) (void*) new_list_tree_node_0);
    dummy_var ^= ((int64_t) (void*) new_uint_8_list_0);
    dummy_var ^= ((int64_t) (void*) free_WireSyncReturnStruct);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}