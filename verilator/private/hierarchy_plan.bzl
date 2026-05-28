"""Hierarchy planning helpers for Verilator rules."""

load(":common.bzl", "partition_verilog_inputs")

def _library_key(label):
    return str(label)

def _new_hierarchy_node(node_name):
    return {
        "children": [],
        "compile_files": [],
        "includes": [],
        "name": node_name,
        "runfiles": [],
    }

def _new_hierarchy_node_state():
    return {
        "children": {},
        "compile_files": {},
        "includes": {},
        "runfiles": {},
    }

def _ensure_node(nodes, node_name):
    node = nodes.get(node_name)
    if node == None:
        node = _new_hierarchy_node(node_name)
        nodes[node_name] = node
    return node

def _append_unique_file(files, seen_paths, file):
    if file.path in seen_paths:
        return
    seen_paths[file.path] = True
    files.append(file)

def _append_unique_string(items, seen_items, item):
    if not item or item in seen_items:
        return
    seen_items[item] = True
    items.append(item)

def _attach_local_inputs(node, node_state, library):
    partitions = partition_verilog_inputs(library.srcs + library.hdrs + library.data)
    for file in partitions.verilog_files:
        _append_unique_file(node["compile_files"], node_state["compile_files"], file)
    for file in partitions.runfiles:
        _append_unique_file(node["runfiles"], node_state["runfiles"], file)
    for include in library.includes:
        _append_unique_string(node["includes"], node_state["includes"], include)

def _ensure_plan_node(nodes, node_state, node_labels, node_name, owner_label):
    node = _ensure_node(nodes, node_name)
    if node_name not in node_state:
        node_state[node_name] = _new_hierarchy_node_state()
    if owner_label != None:
        owner_key = _library_key(owner_label)
        if node_name not in node_labels:
            node_labels[node_name] = owner_key
        elif node_labels[node_name] != owner_key:
            fail("Hierarchical node '{}' is declared by both {} and {}.".format(
                node_name,
                node_labels[node_name],
                owner_label,
            ))
    return node, node_state[node_name]

def build_hierarchy_plan(root_info, root_module_top):
    """Convert a verilog_library DAG into a hierarchical Verilator compile plan.

    Libraries with `top_module` become hierarchy boundaries. Libraries without
    one remain transparent and are merged into the nearest ancestor boundary.

    Args:
        root_info: The graph provider collected from the root verilog_library.
        root_module_top: The resolved root top module name for this build.

    Returns:
        A struct containing the root node name, node compile order, and per-node
        compile metadata.
    """
    nodes = {}
    node_state = {}
    node_labels = {root_module_top: _library_key(root_info.label)}
    node_parents = {}
    libraries_by_label = {}
    owner_by_label = {}
    node_order = []
    seen_nodes = {}

    root_label_key = _library_key(root_info.label)
    for library in root_info.postorder_libraries:
        libraries_by_label[_library_key(library.label)] = library

        # The root target is always represented by `root_module_top`, which may
        # be an explicit override. Do not also materialize the root library's
        # own `top_module` as a second node candidate.
        if (
            _library_key(library.label) != root_label_key and
            library.top_module and
            library.top_module not in seen_nodes
        ):
            seen_nodes[library.top_module] = True
            node_order.append(library.top_module)

    root_node, root_state = _ensure_plan_node(nodes, node_state, node_labels, root_module_top, root_info.label)
    _attach_local_inputs(root_node, root_state, root_info)
    owner_by_label[root_label_key] = root_module_top
    if root_module_top not in seen_nodes:
        node_order.append(root_module_top)

    for library in reversed(root_info.postorder_libraries):
        library_label = _library_key(library.label)
        owner_name = owner_by_label.get(library_label)
        if owner_name == None:
            continue

        owner_node, owner_state = _ensure_plan_node(nodes, node_state, node_labels, owner_name, None)
        _attach_local_inputs(owner_node, owner_state, library)

        # Walk from parent libraries toward their direct deps. A dep with its own
        # `top_module` starts a new node; otherwise it inherits the current owner.
        for dep_label in library.dep_labels:
            child_info = libraries_by_label[_library_key(dep_label)]
            child_top = child_info.top_module
            if child_top:
                _ensure_plan_node(nodes, node_state, node_labels, child_top, child_info.label)
                parent_name = node_parents.get(child_top)
                if parent_name == None:
                    node_parents[child_top] = owner_name
                elif parent_name != owner_name:
                    fail("Hierarchical node '{}' is reachable from both '{}' and '{}'.".format(
                        child_top,
                        parent_name,
                        owner_name,
                    ))
                if child_top not in owner_state["children"]:
                    owner_state["children"][child_top] = True
                    owner_node["children"].append(child_top)
                owner_by_label[_library_key(child_info.label)] = child_top
            else:
                owner_by_label[_library_key(child_info.label)] = owner_name

    return struct(
        root = root_module_top,
        node_names = node_order,
        nodes = nodes,
    )
