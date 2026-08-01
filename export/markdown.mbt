///|
pub fn export_markdown_summary(graph : @core.LineageGraph) -> String {
  let sb = StringBuilder::new()
  sb.write_string("# Data Lineage and Column Impact Analysis Report\n\n")

  // 1. Datasets section
  sb.write_string("## Registered Datasets\n\n")
  for id, ds in graph.datasets {
    sb.write_string("### Dataset: `" + id + "` (" + ds.name + ")\n\n")
    sb.write_string("- **Type**: " + ds.dataset_type + "\n")
    sb.write_string("- **Version**: " + ds.version + "\n")
    if ds.location != "" {
      sb.write_string("- **Location**: `" + ds.location + "`\n")
    }
    if ds.description != "" {
      sb.write_string("- **Description**: " + ds.description + "\n")
    }
    sb.write_string("\n#### Schema\n\n")
    sb.write_string("| Field Name | Data Type | Description | Tags |\n")
    sb.write_string("|---|---|---|---|\n")
    for f in ds.schema {
      let tags_str = if f.tags.length() > 0 {
        f.tags.iter().join(", ")
      } else {
        "-"
      }
      let desc = if f.description != "" { f.description } else { "-" }
      sb.write_string(
        "| `" +
        f.name +
        "` | `" +
        f.data_type +
        "` | " +
        desc +
        " | " +
        tags_str +
        " |\n",
      )
    }
    sb.write_string("\n")
  }

  // 2. Dataset flow section
  sb.write_string("## Dataset Lineage Flow\n\n")
  sb.write_string("| Downstream Dataset | Direct Upstream Datasets |\n")
  sb.write_string("|---|---|\n")
  for downstream_id, upstreams in graph.dataset_dependencies {
    let upstreams_str = if upstreams.length() > 0 {
      let formatted = []
      for up in upstreams {
        formatted.push("`" + up + "`")
      }
      formatted.iter().join(", ")
    } else {
      "-"
    }
    sb.write_string("| `" + downstream_id + "` | " + upstreams_str + " |\n")
  }
  sb.write_string("\n")

  // 3. Column level lineage mapping section
  sb.write_string("## Column-Level Mapping & Impact Rules\n\n")
  sb.write_string(
    "| Target Column | Source Column(s) | Transformation Rule / Expression |\n",
  )
  sb.write_string("|---|---|---|\n")
  for target_id, deps in graph.field_dependencies {
    for dep in deps {
      let target_col = "`" + target_id + "." + dep.target_field + "`"
      let sources = []
      for src in dep.source_fields {
        sources.push("`" + src + "`")
      }
      let sources_str = sources.iter().join(", ")
      let expr_str = if dep.expression != "" {
        "`" + dep.expression + "`"
      } else {
        "-"
      }
      sb.write_string(
        "| " + target_col + " | " + sources_str + " | " + expr_str + " |\n",
      )
    }
  }

  sb.to_string()
}
