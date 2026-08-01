///|
test "registry and basic validation" {
  let reg = Registry::new()

  // Register datasets
  let schema1 = [Field::new("id", "Int"), Field::new("name", "String")]
  let _ = reg.register_dataset("t1", "Table 1", schema1, dataset_type="source")

  let schema2 = [
    Field::new("id", "Int"),
    Field::new("t1_name", "String"),
    Field::new("age", "Int"),
  ]
  let _ = reg.register_dataset("t2", "Table 2", schema2, dataset_type="derived")

  // Register field dependency
  reg.register_field_dependency("t2", "t1_name", ["t1.name"], "t1.name")

  // Validate - should be no errors
  let errs = reg.validate()
  assert_eq(errs.length(), 0)
}

///|
test "validation with errors" {
  let reg = Registry::new()

  let schema1 = [Field::new("id", "Int")]
  let _ = reg.register_dataset("t1", "Table 1", schema1)

  // Refer to non-existing target/source fields/datasets
  reg.register_field_dependency("t1", "missing_field", ["t2.id"], "t2.id")

  let errs = reg.validate()
  // Errors should include missing target field and missing source dataset t2
  assert_eq(errs.length(), 2)
}

///|
test "cycle detection" {
  let reg = Registry::new()
  let schema = [Field::new("id", "Int")]

  let _ = reg.register_dataset("t1", "Table 1", schema)
  let _ = reg.register_dataset("t2", "Table 2", schema)
  let _ = reg.register_dataset("t3", "Table 3", schema)

  // Introduce cycle: t1 -> t2 -> t3 -> t1
  let _ = reg.register_step("step1", "Step 1", Projection, "", inputs=["t1"], outputs=[
    "t2",
  ])
  let _ = reg.register_step("step2", "Step 2", Projection, "", inputs=["t2"], outputs=[
    "t3",
  ])
  let _ = reg.register_step("step3", "Step 3", Projection, "", inputs=["t3"], outputs=[
    "t1",
  ])

  let errs = reg.validate()
  assert_eq(errs.length(), 1)
  // Ensure the error message mentions the circular dependency
  let contains_cycle = errs[0].contains("Circular dependency")
  assert_eq(contains_cycle, true)
}

///|
test "data catalog and pii propagation" {
  let reg = Registry::new()
  let users_schema = [
    Field::new("id", "Int", tags=["pii"]),
    Field::new("name", "String"),
  ]
  let dashboard_schema = [
    Field::new("user_id", "Int"),
    Field::new("user_name", "String"),
  ]
  let _ = reg.register_dataset(
    "users",
    "Users Raw",
    users_schema,
    dataset_type="source",
  )
  let _ = reg.register_dataset(
    "dashboard",
    "Dashboard Target",
    dashboard_schema,
    dataset_type="target",
  )

  reg.register_field_dependency(
    "dashboard",
    "user_name",
    ["users.name"],
    "users.name",
  )
  reg.register_field_dependency(
    "dashboard",
    "user_id",
    ["users.id"],
    "users.id",
  )

  let graph = reg.get_graph()
  let catalog = build_catalog(graph)

  assert_eq(catalog.pii_columns.length(), 1)
  assert_eq(catalog.pii_columns[0], "users.id")

  let propagated = trace_pii_propagation(graph, catalog)
  assert_eq(propagated.length(), 1)
  assert_eq(propagated[0], "dashboard.user_id")
}
