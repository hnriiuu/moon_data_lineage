///|
fn main {
  println(
    "================================================================================",
  )
  println(
    "     MoonBit Data Lineage and Column-Level Impact Analysis Library (Tour)",
  )
  println(
    "================================================================================",
  )

  let reg = @core.Registry::new()

  // 1. Define schemas for source datasets
  println("[1/7] Initializing data warehouse source tables...")
  let users_schema = [
    @core.Field::new("id", "Int", description="Unique user identifier", tags=[
      "pii",
    ]),
    @core.Field::new("name", "String", description="Name of the user"),
    @core.Field::new("email", "String", description="Contact email", tags=[
      "pii",
    ]),
    @core.Field::new("signup_date", "Date"),
  ]
  let _ = reg.register_dataset(
    "users",
    "users_raw",
    users_schema,
    dataset_type="source",
    location="s3://raw/users",
  )

  let orders_schema = [
    @core.Field::new("id", "Int", description="Order identifier"),
    @core.Field::new("user_id", "Int", description="FK referencing users.id"),
    @core.Field::new("amount", "Float", description="Total order amount"),
    @core.Field::new("order_date", "Date"),
  ]
  let _ = reg.register_dataset(
    "orders",
    "orders_raw",
    orders_schema,
    dataset_type="source",
    location="s3://raw/orders",
  )

  let payments_schema = [
    @core.Field::new("id", "Int", description="Payment identifier"),
    @core.Field::new("order_id", "Int", description="FK referencing orders.id"),
    @core.Field::new(
      "payment_method",
      "String",
      description="Credit card, paypal, etc.",
    ),
    @core.Field::new("status", "String", description="SUCCESS or FAILED"),
  ]
  let _ = reg.register_dataset(
    "payments",
    "payments_raw",
    payments_schema,
    dataset_type="source",
    location="s3://raw/payments",
  )
  println("Registered source tables: `users`, `orders`, `payments`.")
  println("")

  // 2. Parse ETL SQL statements to extract lineage flow
  println("[2/7] Extracting lineage by parsing ETL SQL scripts...")
  let graph = reg.get_graph()

  let sql1 = "CREATE VIEW user_spending AS SELECT u.id AS user_id, u.name, o.amount FROM users u JOIN orders o ON u.id = o.user_id"
  println("Parsing SQL 1: " + sql1)
  match @sql.extract_lineage_from_sql(graph, sql1) {
    Ok(_) => println("Successfully extracted lineage for view `user_spending`.")
    Err(e) => println("Error parsing SQL 1: " + e)
  }

  let sql2 = "INSERT INTO executive_dashboard SELECT us.name, us.amount, p.payment_method FROM user_spending us JOIN payments p ON us.user_id = p.id WHERE p.status = 'SUCCESS'"
  println("Parsing SQL 2: " + sql2)
  match @sql.extract_lineage_from_sql(graph, sql2) {
    Ok(_) =>
      println("Successfully extracted lineage for table `executive_dashboard`.")
    Err(e) => println("Error parsing SQL 2: " + e)
  }
  println("")

  // Update executive_dashboard dataset type to target for our reports
  match graph.datasets.get("executive_dashboard") {
    Some(ds) => {
      ds.dataset_type = "target"
      ds.description = "Executive BI revenue dashboard"
    }
    None => ()
  }

  // 3. Run validation checks and linting
  println("[3/7] Running validation checks and query linting...")
  let errors = reg.validate()
  if errors.length() == 0 {
    println("Validation SUCCESS: No cycles or unregistered dependencies found.")
  } else {
    println(
      "Validation FAILURE: Found " + errors.length().to_string() + " issues:",
    )
    for err in errors {
      println("  - " + err)
    }
  }

  let lint_sql = "SELECT * FROM users JOIN orders"
  println("Linting problematic SQL: `" + lint_sql + "`")
  let lint_tokens = @sql.Lexer::new(lint_sql).tokenize()
  let lint_parser = @sql.Parser::new(lint_tokens)
  match lint_parser.parse_stmt() {
    Ok(stmt) => {
      let issues = @analysis.lint_stmt(stmt)
      for issue in issues {
        println(
          "  - [" + issue.severity + "] " + issue.rule_id + ": " + issue.message,
        )
      }
    }
    Err(e) => println("Error parsing lint sql: " + e)
  }
  println("")

  // 4. Trace lineage (Upstream and Downstream)
  println("[4/7] Tracing column-level lineage (field impact dependencies)...")

  // Trace upstream of executive_dashboard.amount
  println("Tracing Upstream for `executive_dashboard.amount`:")
  let upstream_path = @analysis.trace_field_upstream(
    graph, "executive_dashboard", "amount",
  )
  for up in upstream_path {
    println("  <- " + up)
  }

  // Trace downstream of orders.amount
  println("\nTracing Downstream for `orders.amount`:")
  let downstream_path = @analysis.trace_field_downstream(
    graph, "orders", "amount",
  )
  for down in downstream_path {
    println("  -> " + down)
  }
  println("")

  // 5. Downstream impact risk assessment and governance reports
  println("[5/7] Generating Downstream Risk and Governance Reports...")

  // Build and print Data Catalog metadata
  let catalog = @core.build_catalog(graph)
  println("Data Catalog - Sensitive (PII) Columns:")
  for pii_col in catalog.pii_columns {
    println("  - `" + pii_col + "` (Sensitive)")
  }

  // Trace and print PII propagation
  let propagated_pii = @core.trace_pii_propagation(graph, catalog)
  println("\nPII Sensitivity Downstream Propagation Audit:")
  for col in propagated_pii {
    println(
      "  - `" + col + "` inherits PII sensitivity from upstream source(s)",
    )
  }
  println("")

  // Tracing all paths between orders.amount and executive_dashboard.amount
  println(
    "Tracing all paths between `orders.amount` and `executive_dashboard.amount`:",
  )
  let paths = @analysis.trace_all_field_paths(
    graph, "orders.amount", "executive_dashboard.amount",
  )
  println(@analysis.format_column_paths(paths))
  println("")

  let risk_report = @analysis.generate_dataset_risk_report(graph, "users")
  println("Risk Report for modifying dataset `" + risk_report.source + "`:")
  for item in risk_report.items {
    println(
      "  - Target: `" + item.target_id + "` | Risk: [" + item.risk_level + "]",
    )
    println("    Path: " + item.path.iter().join(" -> "))
    println("    Reason: " + item.reason)
  }
  println("")

  // 6. Graph comparison (Diff engine)
  println(
    "[6/7] Computing lineage diff comparison after updating pipeline schemas...",
  )
  // Clone current graph to simulate modified graph
  let new_reg = @core.Registry::new()
  let _ = new_reg.register_dataset("users", "users_raw", users_schema)
  let _ = new_reg.register_dataset("orders", "orders_raw", orders_schema)
  // Register modified dashboard schema (e.g. column 'amount' renamed to 'total_amount')
  let modified_dashboard_schema = [
    @core.Field::new("name", "String"),
    @core.Field::new("total_amount", "Float"), // renamed column
    @core.Field::new("payment_method", "String"),
  ]
  let _ = new_reg.register_dataset(
    "executive_dashboard", "executive_dashboard", modified_dashboard_schema,
  )

  let old_graph = graph
  let new_graph = new_reg.get_graph()

  let diff_report = @diff.compare_graphs(old_graph, new_graph)
  println("Differences Report:")
  println("  Added datasets: " + diff_report.added_datasets.iter().join(", "))
  println(
    "  Deleted datasets: " + diff_report.deleted_datasets.iter().join(", "),
  )
  println("  Modified datasets:")
  for ds_diff in diff_report.modified_datasets {
    println("    - Dataset: `" + ds_diff.dataset_id + "`")
    if ds_diff.added_fields.length() > 0 {
      println("      Added columns: " + ds_diff.added_fields.iter().join(", "))
    }
    if ds_diff.deleted_fields.length() > 0 {
      println(
        "      Deleted columns: " + ds_diff.deleted_fields.iter().join(", "),
      )
    }
  }
  println("")

  // 7. Visualizations and Summaries Exporters
  println("[7/7] Generating visualization outputs and documentation...")

  // Generate Markdown report
  let md_summary = @export.export_markdown_summary(graph)
  println("\n--- Generated Markdown summary (Snippet) ---")
  let md_lines = md_summary.split("\n").to_array()
  let print_limit = if md_lines.length() < 15 { md_lines.length() } else { 15 }
  for idx in 0..<print_limit {
    println(md_lines[idx])
  }
  println("... (truncated)")

  // Generate Mermaid diagram definitions
  let mermaid_ds = @export.export_mermaid_dataset_level(graph)
  println("\n--- Generated Mermaid Dataset-Level diagram definition ---")
  println(mermaid_ds)

  let mermaid_fd = @export.export_mermaid_field_level(graph)
  println("\n--- Generated Mermaid Field-Level diagram definition ---")
  let fd_lines = mermaid_fd.split("\n").to_array()
  let fd_limit = if fd_lines.length() < 15 { fd_lines.length() } else { 15 }
  for idx in 0..<fd_limit {
    println(fd_lines[idx])
  }
  println("... (truncated)")

  println(
    "================================================================================",
  )
  println(
    "                          Data Lineage Tour Completed                           ",
  )
  println(
    "================================================================================",
  )
}
