///|
pub(all) struct Registry {
  graph : LineageGraph
} derive(Eq, Debug)

///|
pub fn Registry::new() -> Registry {
  { graph: LineageGraph::new() }
}

///|
pub fn Registry::get_graph(self : Registry) -> LineageGraph {
  self.graph
}

///|
pub fn Registry::register_dataset(
  self : Registry,
  id : String,
  name : String,
  schema : Array[Field],
  description? : String = "",
  dataset_type? : String = "derived",
  location? : String = "",
  version? : String = "1.0.0",
) -> Dataset {
  let dataset = Dataset::new(
    id,
    name,
    schema,
    description~,
    dataset_type~,
    location~,
    version~,
  )
  self.graph.add_dataset(dataset)
  dataset
}

///|
pub fn Registry::register_step(
  self : Registry,
  id : String,
  name : String,
  step_type : StepType,
  query : String,
  description? : String = "",
  inputs? : Array[String] = [],
  outputs? : Array[String] = [],
) -> Step {
  let step = Step::new(
    id,
    name,
    step_type,
    query,
    description~,
    inputs~,
    outputs~,
  )
  self.graph.add_step(step)
  step
}

///|
pub fn Registry::register_field_dependency(
  self : Registry,
  downstream_id : String,
  target_field : String,
  source_fields : Array[String],
  expression : String,
) -> Unit {
  let dep = FieldDependency::new(target_field, source_fields, expression)
  self.graph.add_field_dependency(downstream_id, dep)
}

///|
pub fn Registry::validate(self : Registry) -> Array[String] {
  self.graph.validate()
}
