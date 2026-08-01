///|
pub(all) struct RiskItem {
  target_id : String
  risk_level : String // "High", "Medium", "Low"
  path : Array[String]
  reason : String
} derive(Eq, Debug)

///|
pub(all) struct RiskReport {
  source : String
  items : Array[RiskItem]
} derive(Eq, Debug)

///|
fn build_dataset_risk_items(
  current : String,
  graph : @core.LineageGraph,
  path : Array[String],
  visited : Map[String, Bool],
  items : Array[RiskItem],
) -> Unit {
  visited.set(current, true)

  for downstream, upstreams in graph.dataset_dependencies {
    if upstreams.contains(current) {
      if visited.get(downstream).unwrap_or(false) == false {
        let new_path = path.copy()
        new_path.push(downstream)

        let depth = new_path.length()
        let risk_level = if depth == 1 {
          "High"
        } else if depth == 2 {
          "Medium"
        } else {
          "Low"
        }

        let ds_type = match graph.datasets.get(downstream) {
          Some(ds) => ds.dataset_type
          None => "derived"
        }

        let reason = if ds_type == "target" {
          "Impacts final business output/target dataset directly or indirectly."
        } else if depth == 1 {
          "Direct downstream consumer. High risk of immediate schema breakage."
        } else {
          "Indirect downstream consumer. Check for cascading schema errors."
        }

        items.push({
          target_id: downstream,
          risk_level,
          path: new_path.copy(),
          reason,
        })

        build_dataset_risk_items(downstream, graph, new_path, visited, items)
      }
    }
  }
}

///|
pub fn generate_dataset_risk_report(
  graph : @core.LineageGraph,
  dataset_id : String,
) -> RiskReport {
  let visited : Map[String, Bool] = Map([])
  let items = []
  build_dataset_risk_items(dataset_id, graph, [], visited, items)
  { source: dataset_id, items }
}

///|
fn build_field_risk_items(
  current_dataset : String,
  current_field : String,
  graph : @core.LineageGraph,
  path : Array[String],
  visited : Map[String, Bool],
  items : Array[RiskItem],
) -> Unit {
  let key = current_dataset + "." + current_field
  visited.set(key, true)

  for downstream_id, deps in graph.field_dependencies {
    for dep in deps {
      if dep.source_fields.contains(key) {
        let target_key = downstream_id + "." + dep.target_field
        if visited.get(target_key).unwrap_or(false) == false {
          let new_path = path.copy()
          new_path.push(target_key)

          let depth = new_path.length()
          let risk_level = if depth == 1 {
            "High"
          } else if depth == 2 {
            "Medium"
          } else {
            "Low"
          }

          let reason = if depth == 1 {
            "Direct column dependency. Modifying or deleting this column will break this downstream column."
          } else {
            "Transitive column dependency. May cause cascading calculation errors."
          }

          items.push({
            target_id: target_key,
            risk_level,
            path: new_path.copy(),
            reason,
          })

          build_field_risk_items(
            downstream_id,
            dep.target_field,
            graph,
            new_path,
            visited,
            items,
          )
        }
      }
    }
  }
}

///|
pub fn generate_field_risk_report(
  graph : @core.LineageGraph,
  dataset_id : String,
  field_name : String,
) -> RiskReport {
  let visited : Map[String, Bool] = Map([])
  let items = []
  let key = dataset_id + "." + field_name
  build_field_risk_items(dataset_id, field_name, graph, [], visited, items)
  { source: key, items }
}
