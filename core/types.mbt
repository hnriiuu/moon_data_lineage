///|
pub(all) struct Field {
  name : String
  data_type : String
  description : String
  tags : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct Dataset {
  id : String
  name : String
  schema : Array[Field]
  description : String
  dataset_type : String // "source", "derived", "target"
  location : String
  version : String
} derive(Eq, Debug)

///|
pub(all) enum StepType {
  Projection
  Join
  Filter
  Aggregate
  Union
  Custom(String)
} derive(Eq, Debug)

///|
pub(all) struct Step {
  id : String
  name : String
  step_type : StepType
  query : String
  description : String
  inputs : Array[String] // List of input dataset IDs
  outputs : Array[String] // List of output dataset IDs
} derive(Eq, Debug)

///|
pub(all) struct FieldDependency {
  target_field : String // E.g., "target_field"
  source_fields : Array[String] // E.g., ["source_dataset.field1", "source_dataset.field2"]
  expression : String // E.g., "source_dataset.field1 + source_dataset.field2"
} derive(Eq, Debug)

///|
pub fn Field::new(
  name : String,
  data_type : String,
  description? : String = "",
  tags? : Array[String] = [],
) -> Field {
  { name, data_type, description, tags }
}

///|
pub fn Dataset::new(
  id : String,
  name : String,
  schema : Array[Field],
  description? : String = "",
  dataset_type? : String = "derived",
  location? : String = "",
  version? : String = "1.0.0",
) -> Dataset {
  { id, name, schema, description, dataset_type, location, version }
}

///|
pub fn Step::new(
  id : String,
  name : String,
  step_type : StepType,
  query : String,
  description? : String = "",
  inputs? : Array[String] = [],
  outputs? : Array[String] = [],
) -> Step {
  { id, name, step_type, query, description, inputs, outputs }
}

///|
pub fn FieldDependency::new(
  target_field : String,
  source_fields : Array[String],
  expression : String,
) -> FieldDependency {
  { target_field, source_fields, expression }
}
