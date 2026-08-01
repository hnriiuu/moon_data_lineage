///|
pub(all) struct ColumnPath {
  path : Array[String]
} derive(Eq, Debug)

///|
fn find_paths_dfs(
  current : String,
  target : String,
  graph : @core.LineageGraph,
  visited : Map[String, Bool],
  current_path : Array[String],
  all_paths : Array[ColumnPath],
) -> Unit {
  visited.set(current, true)
  current_path.push(current)

  if current == target {
    all_paths.push({ path: current_path.copy() })
  } else {
    // Traverse downstreams
    for downstream_id, deps in graph.field_dependencies {
      for dep in deps {
        if dep.source_fields.contains(current) {
          let next_col = downstream_id + "." + dep.target_field
          if visited.get(next_col).unwrap_or(false) == false {
            find_paths_dfs(
              next_col, target, graph, visited, current_path, all_paths,
            )
          }
        }
      }
    }
  }

  let _ = current_path.pop()
  visited.set(current, false)
}

///|
pub fn trace_all_field_paths(
  graph : @core.LineageGraph,
  source_col : String,
  target_col : String,
) -> Array[ColumnPath] {
  let all_paths = []
  let visited : Map[String, Bool] = Map([])
  let current_path = []

  find_paths_dfs(
    source_col, target_col, graph, visited, current_path, all_paths,
  )
  all_paths
}

///|
pub fn format_column_paths(paths : Array[ColumnPath]) -> String {
  let sb = StringBuilder::new()
  if paths.length() == 0 {
    sb.write_string("No paths found between columns.")
  } else {
    sb.write_string("Found " + paths.length().to_string() + " path(s):\n")
    for idx in 0..<paths.length() {
      let path_str = paths[idx].path.iter().join(" -> ")
      sb.write_string("  [" + (idx + 1).to_string() + "] " + path_str + "\n")
    }
  }
  sb.to_string()
}
