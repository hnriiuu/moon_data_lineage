///|
pub(all) struct LineageGraph {
  datasets : Map[String, Dataset]
  steps : Map[String, Step]
  dataset_dependencies : Map[String, Array[String]] // downstream_dataset_id -> upstream_dataset_ids
  field_dependencies : Map[String, Array[FieldDependency]] // downstream_dataset_id -> field level dependencies
} derive(Eq, Debug)

///|
pub fn LineageGraph::new() -> LineageGraph {
  let datasets : Map[String, Dataset] = Map([])
  let steps : Map[String, Step] = Map([])
  let dataset_dependencies : Map[String, Array[String]] = Map([])
  let field_dependencies : Map[String, Array[FieldDependency]] = Map([])
  { datasets, steps, dataset_dependencies, field_dependencies }
}

///|
pub fn LineageGraph::add_dataset(
  self : LineageGraph,
  dataset : Dataset,
) -> Unit {
  self.datasets.set(dataset.id, dataset)
}

///|
pub fn LineageGraph::add_step(self : LineageGraph, step : Step) -> Unit {
  self.steps.set(step.id, step)

  // Automatically record dataset-level dependency for the step
  for out_id in step.outputs {
    for in_id in step.inputs {
      self.add_dataset_dependency(out_id, in_id)
    }
  }
}

///|
pub fn LineageGraph::add_dataset_dependency(
  self : LineageGraph,
  downstream_id : String,
  upstream_id : String,
) -> Unit {
  let deps = match self.dataset_dependencies.get(downstream_id) {
    Some(arr) => arr
    None => {
      let arr = []
      self.dataset_dependencies.set(downstream_id, arr)
      arr
    }
  }
  if deps.contains(upstream_id) == false {
    deps.push(upstream_id)
  }
}

///|
pub fn LineageGraph::add_field_dependency(
  self : LineageGraph,
  downstream_id : String,
  dep : FieldDependency,
) -> Unit {
  let deps = match self.field_dependencies.get(downstream_id) {
    Some(arr) => arr
    None => {
      let arr = []
      self.field_dependencies.set(downstream_id, arr)
      arr
    }
  }
  deps.push(dep)
}

///|
// Cycle detection helper using DFS.
// Returns Some(cycle_path) if a cycle is found, otherwise None.
fn dfs_find_cycle(
  node : String,
  graph : Map[String, Array[String]],
  visiting : Map[String, Bool],
  visited : Map[String, Bool],
  path : Array[String],
) -> Array[String]? {
  visiting.set(node, true)
  path.push(node)

  match graph.get(node) {
    Some(neighbors) =>
      for neighbor in neighbors {
        if visiting.get(neighbor).unwrap_or(false) {
          // Cycle detected! Find where it starts in the path
          let cycle = []
          let mut start_adding = false
          for p in path {
            if p == neighbor {
              start_adding = true
            }
            if start_adding {
              cycle.push(p)
            }
          }
          cycle.push(neighbor)
          return Some(cycle)
        }
        if visited.get(neighbor).unwrap_or(false) == false {
          match dfs_find_cycle(neighbor, graph, visiting, visited, path) {
            Some(c) => return Some(c)
            None => ()
          }
        }
      }
    None => ()
  }

  let _ = path.pop()
  visiting.set(node, false)
  visited.set(node, true)
  None
}

///|
pub fn LineageGraph::find_dataset_cycle(self : LineageGraph) -> Array[String]? {
  let visiting : Map[String, Bool] = Map([])
  let visited : Map[String, Bool] = Map([])
  let path = []

  for node, _ in self.datasets {
    if visited.get(node).unwrap_or(false) == false {
      match
        dfs_find_cycle(node, self.dataset_dependencies, visiting, visited, path) {
        Some(cycle) => return Some(cycle)
        None => ()
      }
    }
  }
  None
}

///|
pub fn LineageGraph::validate(self : LineageGraph) -> Array[String] {
  let errors = []

  // 1. Check for circular dependencies
  match self.find_dataset_cycle() {
    Some(cycle) => {
      let cycle_str = cycle.iter().join(" -> ")
      errors.push("Circular dependency detected in datasets: " + cycle_str)
    }
    None => ()
  }

  // 2. Validate field level dependency sources and targets
  for target_id, field_deps in self.field_dependencies {
    // Check if target dataset exists
    let target_dataset = match self.datasets.get(target_id) {
      Some(d) => d
      None => {
        errors.push(
          "Field dependency refers to unregistered target dataset: " + target_id,
        )
        continue
      }
    }

    for dep in field_deps {
      // Check if target field exists in target dataset schema
      let mut target_field_exists = false
      for f in target_dataset.schema {
        if f.name == dep.target_field {
          target_field_exists = true
          break
        }
      }
      if target_field_exists == false {
        errors.push(
          "Target field '" +
          dep.target_field +
          "' not found in dataset '" +
          target_id +
          "' schema",
        )
      }

      // Check if all source fields exist in their respective datasets
      for src in dep.source_fields {
        let parts = src.split(".")
        let part_array = parts.to_array()
        if part_array.length() != 2 {
          errors.push(
            "Invalid source field format (expected dataset.field): " + src,
          )
          continue
        }
        let src_dataset_id = part_array[0].to_owned()
        let src_field_name = part_array[1].to_owned()

        let src_dataset = match self.datasets.get(src_dataset_id) {
          Some(d) => d
          None => {
            errors.push(
              "Source field '" +
              src +
              "' refers to unregistered dataset: " +
              src_dataset_id,
            )
            continue
          }
        }

        let mut src_field_exists = false
        for f in src_dataset.schema {
          if f.name == src_field_name {
            src_field_exists = true
            break
          }
        }
        if src_field_exists == false {
          errors.push(
            "Source field '" +
            src_field_name +
            "' not found in dataset '" +
            src_dataset_id +
            "' schema",
          )
        }
      }
    }
  }

  errors
}
