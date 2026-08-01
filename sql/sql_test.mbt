///|
test "sql lexer tokenization" {
  let sql = "SELECT id, name AS fullname, 1.25 FROM users WHERE age = 30"
  let lexer = Lexer::new(sql)
  let tokens = lexer.tokenize()

  assert_eq(tokens[0], Token::Keyword("SELECT"))
  assert_eq(tokens[1], Token::Identifier("id"))
  assert_eq(tokens[2], Token::Symbol(","))
  assert_eq(tokens[3], Token::Identifier("name"))
  assert_eq(tokens[4], Token::Keyword("AS"))
  assert_eq(tokens[5], Token::Identifier("fullname"))
  assert_eq(tokens[6], Token::Symbol(","))
  assert_eq(tokens[7], Token::NumberLiteral("1.25"))
  assert_eq(tokens[8], Token::Keyword("FROM"))
  assert_eq(tokens[9], Token::Identifier("users"))
  assert_eq(tokens[10], Token::Keyword("WHERE"))
  assert_eq(tokens[11], Token::Identifier("age"))
  assert_eq(tokens[12], Token::Symbol("="))
  assert_eq(tokens[13], Token::NumberLiteral("30"))
  assert_eq(tokens[14], Token::EOF)
}

///|
test "sql parser statement" {
  let sql = "CREATE VIEW active_users AS SELECT u.id, u.name FROM users AS u JOIN orders AS o ON u.id = o.user_id WHERE u.status = 'active'"
  let lexer = Lexer::new(sql)
  let tokens = lexer.tokenize()
  let parser = Parser::new(tokens)

  match parser.parse_stmt() {
    Ok(SqlStmt::CreateView(view_name, select)) => {
      assert_eq(view_name, "active_users")
      assert_eq(select.projections.length(), 2)
      assert_eq(
        select.from_table,
        Some(SqlTable::BaseTable("users", Some("u"))),
      )
      assert_eq(select.joins.length(), 1)
      assert_eq(select.joins[0].join_type, "INNER")
    }
    _ => assert_eq(true, false) // Should fail if statement is not parsed correctly
  }
}

///|
test "sql parser expressions and precedence" {
  let sql = "SELECT a + b * c = d FROM t"
  let lexer = Lexer::new(sql)
  let tokens = lexer.tokenize()
  let parser = Parser::new(tokens)

  match parser.parse_stmt() {
    Ok(SqlStmt::Select(select)) => {
      let proj = select.projections[0]
      // Expression should be parsed as: (a + (b * c)) = d due to precedence rules
      let expr_str = expr_to_string(proj.expr)
      assert_eq(expr_str, "((a + (b * c)) = d)")
    }
    _ => assert_eq(true, false)
  }
}

///|
test "sql lineage extraction basic" {
  let graph = @core.LineageGraph::new()

  // Register schemas for sources
  let users_schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("name", "String"),
  ]
  let orders_schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("user_id", "Int"),
    @core.Field::new("amount", "Float"),
  ]
  graph.add_dataset(
    @core.Dataset::new("users", "users", users_schema, dataset_type="source"),
  )
  graph.add_dataset(
    @core.Dataset::new("orders", "orders", orders_schema, dataset_type="source"),
  )

  let sql = "INSERT INTO target_report SELECT u.name AS user_name, o.amount FROM users AS u JOIN orders AS o ON u.id = o.user_id"

  let result = extract_lineage_from_sql(graph, sql)
  assert_true(result is Ok(_))

  // Verify dataset dependencies
  let deps = graph.dataset_dependencies.get("target_report").unwrap_or([])
  assert_eq(deps.length(), 2)
  assert_eq(deps.contains("users"), true)
  assert_eq(deps.contains("orders"), true)

  // Verify field dependencies
  let field_deps = graph.field_dependencies.get("target_report").unwrap_or([])
  assert_eq(field_deps.length(), 2)

  // First field mapping: user_name -> users.name
  let dep1 = field_deps[0]
  assert_eq(dep1.target_field, "user_name")
  assert_eq(dep1.source_fields, ["users.name"])

  // Second field mapping: amount -> orders.amount
  let dep2 = field_deps[1]
  assert_eq(dep2.target_field, "amount")
  assert_eq(dep2.source_fields, ["orders.amount"])
}

///|
test "sql lineage extraction with star expansion" {
  let graph = @core.LineageGraph::new()

  let schema = [
    @core.Field::new("id", "Int"),
    @core.Field::new("val", "String"),
  ]
  graph.add_dataset(
    @core.Dataset::new("tbl", "tbl", schema, dataset_type="source"),
  )

  let sql = "CREATE VIEW view_tbl AS SELECT * FROM tbl"
  let result = extract_lineage_from_sql(graph, sql)
  assert_true(result is Ok(_))

  let field_deps = graph.field_dependencies.get("view_tbl").unwrap_or([])
  assert_eq(field_deps.length(), 2)
  assert_eq(field_deps[0].target_field, "id")
  assert_eq(field_deps[0].source_fields, ["tbl.id"])
  assert_eq(field_deps[1].target_field, "val")
  assert_eq(field_deps[1].source_fields, ["tbl.val"])
}
