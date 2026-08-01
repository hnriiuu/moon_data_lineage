///|
test "graph difference comparison" {
  let reg1 = @core.Registry::new()
  let reg2 = @core.Registry::new()

  let old_schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("name", "String"),
  ]
  let new_schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("fullname", "String"), // name renamed to fullname
    @core.Field::new("age", "Int"), // age added
  ]

  // Set up old graph: ds1, ds2. s1 (ds1 -> ds2)
  let _ = reg1.register_dataset("ds1", "Source Table", old_schema)
  let _ = reg1.register_dataset("ds2", "Target Table", old_schema)
  let _ = reg1.register_step(
    "s1",
    "Step 1",
    Projection,
    "SELECT id, name FROM ds1",
    inputs=["ds1"],
    outputs=["ds2"],
  )

  // Set up new graph: ds2 (schema modified), ds3 (added). ds1 (deleted). s2 (s1 deleted, s2 added)
  let _ = reg2.register_dataset("ds2", "Target Table", new_schema)
  let _ = reg2.register_dataset("ds3", "New Table", old_schema)
  let _ = reg2.register_step(
    "s2",
    "Step 2",
    Projection,
    "SELECT * FROM ds2",
    inputs=["ds2"],
    outputs=["ds3"],
  )

  let diff = compare_graphs(reg1.get_graph(), reg2.get_graph())

  // Check datasets diff
  assert_eq(diff.added_datasets.length(), 1)
  assert_eq(diff.added_datasets[0], "ds3")

  assert_eq(diff.deleted_datasets.length(), 1)
  assert_eq(diff.deleted_datasets[0], "ds1")

  assert_eq(diff.modified_datasets.length(), 1)
  let ds2_diff = diff.modified_datasets[0]
  assert_eq(ds2_diff.dataset_id, "ds2")
  assert_eq(ds2_diff.added_fields.length(), 2) // fullname, age
  assert_eq(ds2_diff.added_fields.contains("fullname"), true)
  assert_eq(ds2_diff.added_fields.contains("age"), true)
  assert_eq(ds2_diff.deleted_fields.length(), 1) // name
  assert_eq(ds2_diff.deleted_fields[0], "name")

  // Check steps diff
  assert_eq(diff.added_steps.length(), 1)
  assert_eq(diff.added_steps[0], "s2")
  assert_eq(diff.deleted_steps.length(), 1)
  assert_eq(diff.deleted_steps[0], "s1")
}
