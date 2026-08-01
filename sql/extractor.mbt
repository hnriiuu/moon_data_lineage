///|
fn extract_cols_from_expr(
  expr : SqlExpr,
  cols : Array[(String?, String)],
) -> Unit {
  match expr {
    SqlExpr::ColRef(tbl_opt, col) => cols.push((tbl_opt, col))
    SqlExpr::Star => cols.push((None, "*"))
    SqlExpr::BinaryOp(left, _, right) => {
      extract_cols_from_expr(left, cols)
      extract_cols_from_expr(right, cols)
    }
    SqlExpr::FuncCall(_, args) =>
      for arg in args {
        extract_cols_from_expr(arg, cols)
      }
    _ => ()
  }
}

///|
pub fn expr_to_string(expr : SqlExpr) -> String {
  match expr {
    SqlExpr::ColRef(tbl_opt, col) =>
      match tbl_opt {
        Some(t) => t + "." + col
        None => col
      }
    SqlExpr::Star => "*"
    SqlExpr::Number(n) => n
    SqlExpr::StringVal(s) => "'" + s + "'"
    SqlExpr::BinaryOp(left, op, right) =>
      "(" + expr_to_string(left) + " " + op + " " + expr_to_string(right) + ")"
    SqlExpr::FuncCall(name, args) => {
      let arg_strs = []
      for arg in args {
        arg_strs.push(expr_to_string(arg))
      }
      name + "(" + arg_strs.iter().join(", ") + ")"
    }
  }
}

///|
fn resolve_source_tables(
  table : SqlTable,
  graph : @core.LineageGraph,
  aliases : Map[String, String],
  source_tables : Array[String],
  temp_id_counter : Map[String, Int],
) -> Result[Unit, String] {
  match table {
    SqlTable::BaseTable(name, alias_opt) => {
      let alias_name = alias_opt.unwrap_or(name)
      aliases.set(alias_name, name)
      if source_tables.contains(name) == false {
        source_tables.push(name)
      }
      Ok(())
    }
    SqlTable::Subquery(select, alias_name) => {
      // Create a temporary view/dataset for the subquery
      let count = temp_id_counter.get("count").unwrap_or(0)
      temp_id_counter.set("count", count + 1)
      let temp_view_name = "subquery_" + count.to_string()

      // Extract subquery lineage
      match
        extract_select_lineage(temp_view_name, select, graph, temp_id_counter) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }

      // Register subquery alias
      aliases.set(alias_name, temp_view_name)
      if source_tables.contains(temp_view_name) == false {
        source_tables.push(temp_view_name)
      }
      Ok(())
    }
  }
}

///|
fn extract_select_lineage(
  target_table : String,
  select : SqlSelect,
  graph : @core.LineageGraph,
  temp_id_counter : Map[String, Int],
) -> Result[Unit, String] {
  let aliases : Map[String, String] = Map([])
  let source_tables = []

  // 1. Resolve FROM table
  match select.from_table {
    Some(tbl) =>
      match
        resolve_source_tables(
          tbl, graph, aliases, source_tables, temp_id_counter,
        ) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    None => ()
  }

  // 2. Resolve JOIN tables
  for join in select.joins {
    match
      resolve_source_tables(
        join.table,
        graph,
        aliases,
        source_tables,
        temp_id_counter,
      ) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }

  // If no source tables, we can't extract dependency
  if source_tables.length() == 0 {
    return Ok(())
  }

  // Register dataset dependencies
  for src in source_tables {
    graph.add_dataset_dependency(target_table, src)
  }

  // 3. Process projections
  let mut col_index = 0
  for proj in select.projections {
    let expr_str = expr_to_string(proj.expr)

    // Determine target field name
    let target_field = match proj.alias_name {
      Some(a) => a
      None =>
        match proj.expr {
          SqlExpr::ColRef(_, col) => col
          _ => {
            let name = "col_" + col_index.to_string()
            col_index = col_index + 1
            name
          }
        }
    }

    // Extract column references
    let referenced_cols : Array[(String?, String)] = []
    extract_cols_from_expr(proj.expr, referenced_cols)

    // Check for wildcard star expansion
    let mut is_star = false
    for col_ref in referenced_cols {
      if col_ref.1 == "*" {
        is_star = true
      }
    }

    if is_star {
      // Expand * for all source tables
      for _, actual_table in aliases {
        match graph.datasets.get(actual_table) {
          Some(ds) =>
            for f in ds.schema {
              let src_field = actual_table + "." + f.name
              let dep = @core.FieldDependency::new(
                f.name,
                [src_field],
                src_field,
              )
              graph.add_field_dependency(target_table, dep)
            }
          None => {
            // If schema not found, register a generic field dependency mapping
            let src_field = actual_table + ".*"
            let dep = @core.FieldDependency::new("*", [src_field], src_field)
            graph.add_field_dependency(target_table, dep)
          }
        }
      }
      continue
    }

    // Map referenced columns to source_fields in format "table.column"
    let source_fields = []
    for col_ref in referenced_cols {
      let col_name = col_ref.1
      match col_ref.0 {
        Some(tbl_alias) => {
          let actual_table = aliases.get(tbl_alias).unwrap_or(tbl_alias)
          source_fields.push(actual_table + "." + col_name)
        }
        None => {
          // Resolve which table has this column
          let mut resolved_table = source_tables[0]
          for _, actual_table in aliases {
            match graph.datasets.get(actual_table) {
              Some(ds) => {
                let mut has_col = false
                for f in ds.schema {
                  if f.name == col_name {
                    has_col = true
                    break
                  }
                }
                if has_col {
                  resolved_table = actual_table
                  break
                }
              }
              None => ()
            }
          }
          source_fields.push(resolved_table + "." + col_name)
        }
      }
    }

    let dep = @core.FieldDependency::new(target_field, source_fields, expr_str)
    graph.add_field_dependency(target_table, dep)
  }

  // Ensure the target dataset itself exists in the graph.
  // If not, we register it with the schemas of projections.
  if graph.datasets.contains(target_table) == false {
    let schema = []
    let mut col_idx = 0
    for proj in select.projections {
      let name = match proj.alias_name {
        Some(a) => a
        None =>
          match proj.expr {
            SqlExpr::ColRef(_, col) => col
            _ => {
              let n = "col_" + col_idx.to_string()
              col_idx = col_idx + 1
              n
            }
          }
      }
      schema.push(@core.Field::new(name, "Unknown"))
    }
    let target_ds = @core.Dataset::new(
      target_table,
      target_table,
      schema,
      dataset_type="derived",
    )
    graph.add_dataset(target_ds)
  }

  Ok(())
}

///|
pub fn extract_lineage_from_sql(
  graph : @core.LineageGraph,
  sql : String,
) -> Result[Unit, String] {
  let lexer = Lexer::new(sql)
  let tokens = lexer.tokenize()
  let parser = Parser::new(tokens)

  let stmt = match parser.parse_stmt() {
    Ok(s) => s
    Err(e) => return Err(e)
  }

  let temp_id_counter : Map[String, Int] = Map([])

  match stmt {
    SqlStmt::Select(select) =>
      match
        extract_select_lineage("output_result", select, graph, temp_id_counter) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    SqlStmt::Insert(target_table, select) =>
      match
        extract_select_lineage(target_table, select, graph, temp_id_counter) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    SqlStmt::CreateView(view_name, select) =>
      match extract_select_lineage(view_name, select, graph, temp_id_counter) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
  }
}
