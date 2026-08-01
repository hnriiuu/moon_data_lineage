///|
test "exporters verification" {
  let reg = @core.Registry::new()
  let schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("name", "String"),
  ]
  let _ = reg.register_dataset("t1", "Table 1", schema, dataset_type="source")
  let _ = reg.register_dataset("t2", "Table 2", schema, dataset_type="target")
  let _ = reg.register_step(
    "s1",
    "Step 1",
    Projection,
    "SELECT id, name FROM t1",
    inputs=["t1"],
    outputs=["t2"],
  )
  reg.register_field_dependency("t2", "name", ["t1.name"], "t1.name")

  let graph = reg.get_graph()

  // JSON
  let json_str = graph_to_json(graph)
  assert_eq(json_str.contains("\"datasets\":"), true)
  assert_eq(json_str.contains("\"steps\":"), true)

  // Mermaid
  let mermaid_ds = export_mermaid_dataset_level(graph)
  assert_eq(mermaid_ds.contains("graph TD"), true)
  assert_eq(mermaid_ds.contains("t1 --> t2"), true)

  let mermaid_fd = export_mermaid_field_level(graph)
  assert_eq(mermaid_fd.contains("t1__name --> t2__name"), true)

  // DOT
  let dot_ds = export_dot_dataset_level(graph)
  assert_eq(dot_ds.contains("digraph G"), true)

  let dot_fd = export_dot_field_level(graph)
  assert_eq(dot_fd.contains("t1__name"), true)

  // Markdown
  let md = export_markdown_summary(graph)
  assert_eq(md.contains("# Data Lineage"), true)
  assert_eq(md.contains("| Field Name |"), true)

  // HTML
  let html = export_html_dashboard(graph)
  assert_eq(html.contains("<!DOCTYPE html>"), true)
  assert_eq(html.contains("MoonBit Lineage"), true)
}
