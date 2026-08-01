///|
fn trace_dataset_upstream_rec(
  node : String,
  deps : Map[String, Array[String]],
  visited : Map[String, Bool],
  result : Array[String],
) -> Unit {
  visited.set(node, true)
  match deps.get(node) {
    Some(upstreams) =>
      for up in upstreams {
        if visited.get(up).unwrap_or(false) == false {
          result.push(up)
          trace_dataset_upstream_rec(up, deps, visited, result)
        }
      }
    None => ()
  }
}

///|
pub fn trace_dataset_upstream(
  graph : @core.LineageGraph,
  dataset_id : String,
) -> Array[String] {
  let visited : Map[String, Bool] = Map([])
  let result = []
  trace_dataset_upstream_rec(
    dataset_id,
    graph.dataset_dependencies,
    visited,
    result,
  )
  result
}

///|
fn trace_dataset_downstream_rec(
  node : String,
  graph : @core.LineageGraph,
  visited : Map[String, Bool],
  result : Array[String],
) -> Unit {
  visited.set(node, true)

  // Find all datasets that have 'node' as an upstream dependency
  for downstream, upstreams in graph.dataset_dependencies {
    if upstreams.contains(node) {
      if visited.get(downstream).unwrap_or(false) == false {
        result.push(downstream)
        trace_dataset_downstream_rec(downstream, graph, visited, result)
      }
    }
  }
}

///|
pub fn trace_dataset_downstream(
  graph : @core.LineageGraph,
  dataset_id : String,
) -> Array[String] {
  let visited : Map[String, Bool] = Map([])
  let result = []
  trace_dataset_downstream_rec(dataset_id, graph, visited, result)
  result
}

///|
// Trace field level upstream dependencies recursively.
// Returns an array of strings in the format "dataset_id.field_name".
fn trace_field_upstream_rec(
  dataset_id : String,
  field_name : String,
  graph : @core.LineageGraph,
  visited : Map[String, Bool],
  result : Array[String],
) -> Unit {
  let key = dataset_id + "." + field_name
  visited.set(key, true)

  match graph.field_dependencies.get(dataset_id) {
    Some(deps) =>
      for dep in deps {
        if dep.target_field == field_name {
          for src in dep.source_fields {
            if visited.get(src).unwrap_or(false) == false {
              result.push(src)

              let parts = src.split(".")
              let part_array = parts.to_array()
              if part_array.length() == 2 {
                let src_ds = part_array[0].to_owned()
                let src_fd = part_array[1].to_owned()
                trace_field_upstream_rec(src_ds, src_fd, graph, visited, result)
              }
            }
          }
        }
      }
    None => ()
  }
}

///|
pub fn trace_field_upstream(
  graph : @core.LineageGraph,
  dataset_id : String,
  field_name : String,
) -> Array[String] {
  let visited : Map[String, Bool] = Map([])
  let result = []
  trace_field_upstream_rec(dataset_id, field_name, graph, visited, result)
  result
}

///|
// Trace field level downstream dependencies recursively.
// Returns an array of strings in the format "dataset_id.field_name".
fn trace_field_downstream_rec(
  dataset_id : String,
  field_name : String,
  graph : @core.LineageGraph,
  visited : Map[String, Bool],
  result : Array[String],
) -> Unit {
  let key = dataset_id + "." + field_name
  visited.set(key, true)

  // Find all field dependencies where key is a source field
  for downstream_id, deps in graph.field_dependencies {
    for dep in deps {
      if dep.source_fields.contains(key) {
        let next_key = downstream_id + "." + dep.target_field
        if visited.get(next_key).unwrap_or(false) == false {
          result.push(next_key)
          trace_field_downstream_rec(
            downstream_id,
            dep.target_field,
            graph,
            visited,
            result,
          )
        }
      }
    }
  }
}

///|
pub fn trace_field_downstream(
  graph : @core.LineageGraph,
  dataset_id : String,
  field_name : String,
) -> Array[String] {
  let visited : Map[String, Bool] = Map([])
  let result = []
  trace_field_downstream_rec(dataset_id, field_name, graph, visited, result)
  result
}
