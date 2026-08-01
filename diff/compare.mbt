///|
pub(all) struct FieldDiff {
  field_name : String
  old_type : String
  new_type : String
  old_description : String
  new_description : String
} derive(Eq, Debug)

///|
pub(all) struct DatasetDiff {
  dataset_id : String
  added_fields : Array[String]
  deleted_fields : Array[String]
  modified_fields : Array[FieldDiff]
  metadata_changed : Bool
} derive(Eq, Debug)

///|
pub(all) struct StepDiff {
  step_id : String
  inputs_changed : Bool
  outputs_changed : Bool
  query_changed : Bool
} derive(Eq, Debug)

///|
pub(all) struct GraphDiff {
  added_datasets : Array[String]
  deleted_datasets : Array[String]
  modified_datasets : Array[DatasetDiff]
  added_steps : Array[String]
  deleted_steps : Array[String]
  modified_steps : Array[StepDiff]
} derive(Eq, Debug)

///|
pub fn compare_datasets(
  old_ds : @core.Dataset,
  new_ds : @core.Dataset,
) -> DatasetDiff? {
  let added_fields = []
  let deleted_fields = []
  let modified_fields = []

  let old_fields_map : Map[String, @core.Field] = Map([])
  for f in old_ds.schema {
    old_fields_map.set(f.name, f)
  }

  let new_fields_map : Map[String, @core.Field] = Map([])
  for f in new_ds.schema {
    new_fields_map.set(f.name, f)
  }

  // Find added and modified fields
  for f in new_ds.schema {
    match old_fields_map.get(f.name) {
      Some(old_f) =>
        if old_f.data_type != f.data_type || old_f.description != f.description {
          modified_fields.push({
            field_name: f.name,
            old_type: old_f.data_type,
            new_type: f.data_type,
            old_description: old_f.description,
            new_description: f.description,
          })
        }
      None => added_fields.push(f.name)
    }
  }

  // Find deleted fields
  for f in old_ds.schema {
    if new_fields_map.contains(f.name) == false {
      deleted_fields.push(f.name)
    }
  }

  let metadata_changed = old_ds.description != new_ds.description ||
    old_ds.dataset_type != new_ds.dataset_type ||
    old_ds.location != new_ds.location ||
    old_ds.version != new_ds.version

  if added_fields.length() > 0 ||
    deleted_fields.length() > 0 ||
    modified_fields.length() > 0 ||
    metadata_changed {
    Some({
      dataset_id: old_ds.id,
      added_fields,
      deleted_fields,
      modified_fields,
      metadata_changed,
    })
  } else {
    None
  }
}

///|
pub fn compare_steps(old_step : @core.Step, new_step : @core.Step) -> StepDiff? {
  let inputs_changed = old_step.inputs != new_step.inputs
  let outputs_changed = old_step.outputs != new_step.outputs
  let query_changed = old_step.query != new_step.query ||
    old_step.step_type != new_step.step_type

  if inputs_changed || outputs_changed || query_changed {
    Some({
      step_id: old_step.id,
      inputs_changed,
      outputs_changed,
      query_changed,
    })
  } else {
    None
  }
}

///|
pub fn compare_graphs(
  old_graph : @core.LineageGraph,
  new_graph : @core.LineageGraph,
) -> GraphDiff {
  let added_datasets = []
  let deleted_datasets = []
  let modified_datasets = []

  let added_steps = []
  let deleted_steps = []
  let modified_steps = []

  // 1. Compare Datasets
  for id, new_ds in new_graph.datasets {
    match old_graph.datasets.get(id) {
      Some(old_ds) =>
        match compare_datasets(old_ds, new_ds) {
          Some(diff) => modified_datasets.push(diff)
          None => ()
        }
      None => added_datasets.push(id)
    }
  }

  for id, _ in old_graph.datasets {
    if new_graph.datasets.contains(id) == false {
      deleted_datasets.push(id)
    }
  }

  // 2. Compare Steps
  for id, new_step in new_graph.steps {
    match old_graph.steps.get(id) {
      Some(old_step) =>
        match compare_steps(old_step, new_step) {
          Some(diff) => modified_steps.push(diff)
          None => ()
        }
      None => added_steps.push(id)
    }
  }

  for id, _ in old_graph.steps {
    if new_graph.steps.contains(id) == false {
      deleted_steps.push(id)
    }
  }

  {
    added_datasets,
    deleted_datasets,
    modified_datasets,
    added_steps,
    deleted_steps,
    modified_steps,
  }
}
