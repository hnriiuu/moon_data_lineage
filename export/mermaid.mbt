///|
fn escape_mermaid_label(s : String) -> String {
  // Simple helper to avoid quotes in Mermaid labels
  let sb = StringBuilder::new()
  for c in s {
    if c == '"' {
      sb.write_string("'")
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
pub fn export_mermaid_dataset_level(graph : @core.LineageGraph) -> String {
  let sb = StringBuilder::new()
  sb.write_string("graph TD\n")

  // 1. Declare datasets as nodes with names as labels
  for id, ds in graph.datasets {
    sb.write_string("  " + id + "[\"" + escape_mermaid_label(ds.name) + "\"]\n")
  }

  // 2. Draw connections
  for downstream_id, upstreams in graph.dataset_dependencies {
    for up in upstreams {
      sb.write_string("  " + up + " --> " + downstream_id + "\n")
    }
  }

  sb.to_string()
}

///|
fn field_node_id(dataset_id : String, field_name : String) -> String {
  // Convert "ds.field" to "ds__field" for safe Mermaid node identifiers
  dataset_id + "__" + field_name
}

///|
pub fn export_mermaid_field_level(graph : @core.LineageGraph) -> String {
  let sb = StringBuilder::new()
  sb.write_string("graph TD\n")

  // 1. Draw subgraphs for each dataset and declare field nodes inside
  for ds_id, ds in graph.datasets {
    sb.write_string(
      "  subgraph " +
      ds_id +
      " [\"Dataset: " +
      escape_mermaid_label(ds.name) +
      "\"]\n",
    )
    for f in ds.schema {
      let node_id = field_node_id(ds_id, f.name)
      sb.write_string(
        "    " + node_id + "[\"" + f.name + " (" + f.data_type + ")\"]\n",
      )
    }
    sb.write_string("  end\n")
  }

  // 2. Draw field level connections
  for target_id, deps in graph.field_dependencies {
    for dep in deps {
      let target_node = field_node_id(target_id, dep.target_field)
      for src in dep.source_fields {
        let parts = src.split(".")
        let part_array = parts.to_array()
        if part_array.length() == 2 {
          let src_ds = part_array[0].to_owned()
          let src_fd = part_array[1].to_owned()
          let src_node = field_node_id(src_ds, src_fd)

          let edge_label = if dep.expression != "" && dep.expression != src {
            " -- \"" + escape_mermaid_label(dep.expression) + "\" --> "
          } else {
            " --> "
          }
          sb.write_string("  " + src_node + edge_label + target_node + "\n")
        }
      }
    }
  }

  sb.to_string()
}
