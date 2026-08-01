///|
fn escape_json_string(s : String) -> String {
  let sb = StringBuilder::new()
  for c in s {
    if c == '\\' {
      sb.write_string("\\\\")
    } else if c == '"' {
      sb.write_string("\\\"")
    } else if c == '\n' {
      sb.write_string("\\n")
    } else if c == '\t' {
      sb.write_string("\\t")
    } else if c == '\r' {
      sb.write_string("\\r")
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn field_to_json(f : @core.Field) -> String {
  let tags_json = []
  for t in f.tags {
    tags_json.push("\"" + escape_json_string(t) + "\"")
  }
  "{" +
  "\"name\":\"" +
  escape_json_string(f.name) +
  "\"," +
  "\"data_type\":\"" +
  escape_json_string(f.data_type) +
  "\"," +
  "\"description\":\"" +
  escape_json_string(f.description) +
  "\"," +
  "\"tags\":[" +
  tags_json.iter().join(",") +
  "]" +
  "}"
}

///|
fn dataset_to_json(d : @core.Dataset) -> String {
  let fields_json = []
  for f in d.schema {
    fields_json.push(field_to_json(f))
  }
  "{" +
  "\"id\":\"" +
  escape_json_string(d.id) +
  "\"," +
  "\"name\":\"" +
  escape_json_string(d.name) +
  "\"," +
  "\"dataset_type\":\"" +
  escape_json_string(d.dataset_type) +
  "\"," +
  "\"location\":\"" +
  escape_json_string(d.location) +
  "\"," +
  "\"version\":\"" +
  escape_json_string(d.version) +
  "\"," +
  "\"description\":\"" +
  escape_json_string(d.description) +
  "\"," +
  "\"schema\":[" +
  fields_json.iter().join(",") +
  "]" +
  "}"
}

///|
fn step_to_json(s : @core.Step) -> String {
  let inputs_json = []
  for i in s.inputs {
    inputs_json.push("\"" + escape_json_string(i) + "\"")
  }
  let outputs_json = []
  for o in s.outputs {
    outputs_json.push("\"" + escape_json_string(o) + "\"")
  }
  let step_type_str = match s.step_type {
    Projection => "Projection"
    Join => "Join"
    Filter => "Filter"
    Aggregate => "Aggregate"
    Union => "Union"
    Custom(name) => "Custom(" + name + ")"
  }
  "{" +
  "\"id\":\"" +
  escape_json_string(s.id) +
  "\"," +
  "\"name\":\"" +
  escape_json_string(s.name) +
  "\"," +
  "\"step_type\":\"" +
  escape_json_string(step_type_str) +
  "\"," +
  "\"query\":\"" +
  escape_json_string(s.query) +
  "\"," +
  "\"description\":\"" +
  escape_json_string(s.description) +
  "\"," +
  "\"inputs\":[" +
  inputs_json.iter().join(",") +
  "]," +
  "\"outputs\":[" +
  outputs_json.iter().join(",") +
  "]" +
  "}"
}

///|
fn field_dependency_to_json(
  target_ds : String,
  dep : @core.FieldDependency,
) -> String {
  let sources_json = []
  for src in dep.source_fields {
    sources_json.push("\"" + escape_json_string(src) + "\"")
  }
  "{" +
  "\"target_dataset\":\"" +
  escape_json_string(target_ds) +
  "\"," +
  "\"target_field\":\"" +
  escape_json_string(dep.target_field) +
  "\"," +
  "\"expression\":\"" +
  escape_json_string(dep.expression) +
  "\"," +
  "\"source_fields\":[" +
  sources_json.iter().join(",") +
  "]" +
  "}"
}

///|
pub fn graph_to_json(graph : @core.LineageGraph) -> String {
  let datasets_json = []
  for _, d in graph.datasets {
    datasets_json.push(dataset_to_json(d))
  }
  let steps_json = []
  for _, s in graph.steps {
    steps_json.push(step_to_json(s))
  }
  let field_deps_json = []
  for target_id, deps in graph.field_dependencies {
    for dep in deps {
      field_deps_json.push(field_dependency_to_json(target_id, dep))
    }
  }

  "{" +
  "\"datasets\":[" +
  datasets_json.iter().join(",") +
  "]," +
  "\"steps\":[" +
  steps_json.iter().join(",") +
  "]," +
  "\"field_dependencies\":[" +
  field_deps_json.iter().join(",") +
  "]" +
  "}"
}
