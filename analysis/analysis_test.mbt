///|
test "dataset and field tracing" {
  let reg = @core.Registry::new()
  
  let schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("val", "String"),
  ]
  
  let _ = reg.register_dataset("ds1", "Source DS", schema, dataset_type="source")
  let _ = reg.register_dataset("ds2", "Derived DS 1", schema, dataset_type="derived")
  let _ = reg.register_dataset("ds3", "Derived DS 2", schema, dataset_type="derived")
  let _ = reg.register_dataset("ds4", "Target DS", schema, dataset_type="target")
  
  // Register steps to establish dataset flow: ds1 -> ds2 -> ds3 -> ds4
  let _ = reg.register_step("s1", "Step 1", Projection, "", inputs=["ds1"], outputs=["ds2"])
  let _ = reg.register_step("s2", "Step 2", Projection, "", inputs=["ds2"], outputs=["ds3"])
  let _ = reg.register_step("s3", "Step 3", Projection, "", inputs=["ds3"], outputs=["ds4"])
  
  // Field-level dependencies
  reg.register_field_dependency("ds2", "val", ["ds1.val"], "ds1.val")
  reg.register_field_dependency("ds3", "val", ["ds2.val"], "ds2.val")
  reg.register_field_dependency("ds4", "val", ["ds3.val"], "ds3.val")
  
  let graph = reg.get_graph()
  
  // Test dataset upstream/downstream
  let upstream_ds = trace_dataset_upstream(graph, "ds3")
  assert_eq(upstream_ds.length(), 2) // ds2, ds1
  assert_eq(upstream_ds.contains("ds2"), true)
  assert_eq(upstream_ds.contains("ds1"), true)
  
  let downstream_ds = trace_dataset_downstream(graph, "ds2")
  assert_eq(downstream_ds.length(), 2) // ds3, ds4
  assert_eq(downstream_ds.contains("ds3"), true)
  assert_eq(downstream_ds.contains("ds4"), true)
  
  // Test field upstream/downstream
  let upstream_fd = trace_field_upstream(graph, "ds4", "val")
  assert_eq(upstream_fd.length(), 3) // ds3.val, ds2.val, ds1.val
  assert_eq(upstream_fd.contains("ds3.val"), true)
  assert_eq(upstream_fd.contains("ds2.val"), true)
  assert_eq(upstream_fd.contains("ds1.val"), true)
  
  let downstream_fd = trace_field_downstream(graph, "ds1", "val")
  assert_eq(downstream_fd.length(), 3) // ds2.val, ds3.val, ds4.val
  assert_eq(downstream_fd.contains("ds2.val"), true)
  assert_eq(downstream_fd.contains("ds3.val"), true)
  assert_eq(downstream_fd.contains("ds4.val"), true)
}

///|
test "risk reporting" {
  let reg = @core.Registry::new()
  let schema = [@core.Field::new("id", "Int")]
  
  let _ = reg.register_dataset("ds1", "Source", schema, dataset_type="source")
  let _ = reg.register_dataset("ds2", "Derived", schema, dataset_type="derived")
  let _ = reg.register_dataset("ds3", "Target", schema, dataset_type="target")
  
  let _ = reg.register_step("s1", "S1", Projection, "", inputs=["ds1"], outputs=["ds2"])
  let _ = reg.register_step("s2", "S2", Projection, "", inputs=["ds2"], outputs=["ds3"])
  
  reg.register_field_dependency("ds2", "id", ["ds1.id"], "ds1.id")
  reg.register_field_dependency("ds3", "id", ["ds2.id"], "ds2.id")
  
  let graph = reg.get_graph()
  
  let ds_report = generate_dataset_risk_report(graph, "ds1")
  assert_eq(ds_report.items.length(), 2)
  
  // First downstream item (ds2) should be High risk
  assert_eq(ds_report.items[0].target_id, "ds2")
  assert_eq(ds_report.items[0].risk_level, "High")
  
  // Second downstream item (ds3) should be Medium risk, but target type override
  assert_eq(ds_report.items[1].target_id, "ds3")
  assert_eq(ds_report.items[1].risk_level, "Medium")
  assert_eq(ds_report.items[1].reason.contains("business output"), true)
  
  let fd_report = generate_field_risk_report(graph, "ds1", "id")
  assert_eq(fd_report.items.length(), 2)
  assert_eq(fd_report.items[0].target_id, "ds2.id")
  assert_eq(fd_report.items[0].risk_level, "High")
  assert_eq(fd_report.items[1].target_id, "ds3.id")
  assert_eq(fd_report.items[1].risk_level, "Medium")
}

///|
test "query best-practice linter" {
  // Test 1: SELECT * triggers L001 warning
  let sql1 = "SELECT * FROM users"
  let tokens1 = @sql.Lexer::new(sql1).tokenize()
  let parser1 = @sql.Parser::new(tokens1)
  match parser1.parse_stmt() {
    Ok(stmt) => {
      let issues = lint_stmt(stmt)
      assert_eq(issues.length(), 1)
      assert_eq(issues[0].rule_id, "L001")
      assert_eq(issues[0].severity, "Warning")
    }
    _ => assert_true(false)
  }
  
  // Test 2: JOIN without ON triggers L002 error
  let sql2 = "SELECT u.id FROM users u JOIN orders o"
  let tokens2 = @sql.Lexer::new(sql2).tokenize()
  let parser2 = @sql.Parser::new(tokens2)
  match parser2.parse_stmt() {
    Ok(stmt) => {
      let issues = lint_stmt(stmt)
      assert_eq(issues.length() >= 1, true)
      // Check if L002 rule is triggered
      let mut found_l002 = false
      for issue in issues {
        if issue.rule_id == "L002" {
          found_l002 = true
          break
        }
      }
      assert_eq(found_l002, true)
    }
    _ => assert_true(false)
  }
  
  // Test 3: Missing aliases in JOIN triggers L003 warning
  let sql3 = "SELECT users.id, orders.id FROM users JOIN orders ON users.id = orders.user_id"
  let tokens3 = @sql.Lexer::new(sql3).tokenize()
  let parser3 = @sql.Parser::new(tokens3)
  match parser3.parse_stmt() {
    Ok(stmt) => {
      let issues = lint_stmt(stmt)
      debug_inspect(issues, content=(
        #|[
        #|  {
        #|    rule_id: "L003",
        #|    severity: "Warning",
        #|    message: "Table 'users' is missing an alias. When performing JOIN queries, it is best practice to alias all source tables to avoid column qualification ambiguity.",
        #|  },
        #|  {
        #|    rule_id: "L003",
        #|    severity: "Warning",
        #|    message: "Joined table 'orders' is missing an alias. All joined tables should have explicit aliases.",
        #|  },
        #|]
      ))
    }
    _ => assert_true(false)
  }
}

///|
test "column path tracing" {
  let reg = @core.Registry::new()
  let schema = [@core.Field::new("val", "Int")]
  
  let _ = reg.register_dataset("t1", "T1", schema, dataset_type="source")
  let _ = reg.register_dataset("t2", "T2", schema, dataset_type="derived")
  let _ = reg.register_dataset("t3", "T3", schema, dataset_type="derived")
  let _ = reg.register_dataset("t4", "T4", schema, dataset_type="target")
  
  let _ = reg.register_step("s1", "S1", Projection, "", inputs=["t1"], outputs=["t2"])
  let _ = reg.register_step("s2", "S2", Projection, "", inputs=["t2"], outputs=["t3"])
  let _ = reg.register_step("s3", "S3", Projection, "", inputs=["t3"], outputs=["t4"])
  
  // Field-level: t1.val -> t2.val -> t3.val -> t4.val
  reg.register_field_dependency("t2", "val", ["t1.val"], "t1.val")
  reg.register_field_dependency("t3", "val", ["t2.val"], "t2.val")
  reg.register_field_dependency("t4", "val", ["t3.val"], "t3.val")
  
  let graph = reg.get_graph()
  let paths = trace_all_field_paths(graph, "t1.val", "t4.val")
  
  assert_eq(paths.length(), 1)
  assert_eq(paths[0].path, ["t1.val", "t2.val", "t3.val", "t4.val"])
}

///|
test "column path tracing multiple paths" {
  let reg = @core.Registry::new()
  let schema = [@core.Field::new("val", "Int")]
  
  let _ = reg.register_dataset("t1", "T1", schema, dataset_type="source")
  let _ = reg.register_dataset("t2", "T2", schema, dataset_type="derived")
  let _ = reg.register_dataset("t3", "T3", schema, dataset_type="derived")
  let _ = reg.register_dataset("t4", "T4", schema, dataset_type="target")
  
  // Register multi path steps:
  // path 1: t1 -> t2 -> t4
  // path 2: t1 -> t3 -> t4
  let _ = reg.register_step("s1", "S1", Projection, "", inputs=["t1"], outputs=["t2"])
  let _ = reg.register_step("s2", "S2", Projection, "", inputs=["t1"], outputs=["t3"])
  let _ = reg.register_step("s3", "S3", Projection, "", inputs=["t2", "t3"], outputs=["t4"])
  
  reg.register_field_dependency("t2", "val", ["t1.val"], "t1.val")
  reg.register_field_dependency("t3", "val", ["t1.val"], "t1.val")
  reg.register_field_dependency("t4", "val", ["t2.val", "t3.val"], "t2.val + t3.val")
  
  let graph = reg.get_graph()
  let paths = trace_all_field_paths(graph, "t1.val", "t4.val")
  
  assert_eq(paths.length(), 2)
  // Ensure the formatting helper prints correctly
  let fmt = format_column_paths(paths)
  assert_eq(fmt.contains("Found 2 path(s):"), true)
}
