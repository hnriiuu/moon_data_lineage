///|
pub fn export_dot_dataset_level(graph : @core.LineageGraph) -> String {
  let sb = StringBuilder::new()
  sb.write_string("digraph G {\n")
  sb.write_string("  node [shape=box, style=filled, fillcolor=lightblue];\n")

  // Declare nodes
  for id, ds in graph.datasets {
    sb.write_string(
      "  \"" +
      id +
      "\" [label=\"" +
      ds.name +
      " (" +
      ds.dataset_type +
      ")\"];\n",
    )
  }

  // Draw edges
  for downstream_id, upstreams in graph.dataset_dependencies {
    for up in upstreams {
      sb.write_string("  \"" + up + "\" -> \"" + downstream_id + "\";\n")
    }
  }

  sb.write_string("}\n")
  sb.to_string()
}

///|
pub fn export_dot_field_level(graph : @core.LineageGraph) -> String {
  let sb = StringBuilder::new()
  sb.write_string("digraph G {\n")
  sb.write_string("  compound=true;\n")
  sb.write_string("  node [shape=box];\n")

  // Declare subgraphs
  for ds_id, ds in graph.datasets {
    sb.write_string("  subgraph \"cluster_" + ds_id + "\" {\n")
    sb.write_string(
      "    label=\"" + ds.name + " (" + ds.dataset_type + ")\";\n",
    )
    sb.write_string("    style=filled;\n")
    sb.write_string("    color=lightgrey;\n")
    for f in ds.schema {
      let node_id = ds_id + "__" + f.name
      sb.write_string(
        "    \"" +
        node_id +
        "\" [label=\"" +
        f.name +
        " (" +
        f.data_type +
        ")\", style=filled, fillcolor=white];\n",
      )
    }
    sb.write_string("  }\n")
  }

  // Draw edges
  for target_id, deps in graph.field_dependencies {
    for dep in deps {
      let target_node = target_id + "__" + dep.target_field
      for src in dep.source_fields {
        let parts = src.split(".")
        let part_array = parts.to_array()
        if part_array.length() == 2 {
          let src_ds = part_array[0].to_owned()
          let src_fd = part_array[1].to_owned()
          let src_node = src_ds + "__" + src_fd

          let label_attr = if dep.expression != "" && dep.expression != src {
            " [label=\"" + dep.expression + "\"]"
          } else {
            ""
          }
          sb.write_string(
            "  \"" +
            src_node +
            "\" -> \"" +
            target_node +
            "\"" +
            label_attr +
            ";\n",
          )
        }
      }
    }
  }

  sb.write_string("}\n")
  sb.to_string()
}
