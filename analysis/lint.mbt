///|
pub(all) struct LintIssue {
  rule_id : String
  severity : String // "Warning", "Error"
  message : String
} derive(Eq, Debug)

///|
pub impl Show for LintIssue with fn output(self, logger) {
  logger.write_string(
    "LintIssue { rule_id: " +
    self.rule_id +
    ", severity: " +
    self.severity +
    ", message: " +
    self.message +
    " }",
  )
}

///|
fn check_expr_for_star(expr : @sql.SqlExpr) -> Bool {
  match expr {
    @sql.SqlExpr::Star => true
    @sql.SqlExpr::ColRef(_, col) => col == "*"
    @sql.SqlExpr::BinaryOp(left, _, right) =>
      check_expr_for_star(left) || check_expr_for_star(right)
    @sql.SqlExpr::FuncCall(_, args) => {
      let mut found = false
      for arg in args {
        if check_expr_for_star(arg) {
          found = true
          break
        }
      }
      found
    }
    _ => false
  }
}

///|
pub fn lint_select(select : @sql.SqlSelect) -> Array[LintIssue] {
  let issues = []

  // 1. Check for SELECT *
  let mut has_star = false
  for proj in select.projections {
    if check_expr_for_star(proj.expr) {
      has_star = true
      break
    }
  }
  if has_star {
    issues.push({
      rule_id: "L001",
      severity: "Warning",
      message: "Avoid using wildcard 'SELECT *' in production queries. Explicitly declare column names to prevent downstream dependency breakages when schemas update.",
    })
  }

  // 2. Check for missing JOIN ON condition
  for join in select.joins {
    if join.join_type != "CROSS" && join.on_expr is None {
      issues.push({
        rule_id: "L002",
        severity: "Error",
        message: "JOIN query is missing an ON clause. This will result in an accidental Cartesian product (Cross Join) which can degrade performance.",
      })
    }
  }

  // 3. Check if base tables are missing aliases when joins are present
  if select.joins.length() > 0 {
    match select.from_table {
      Some(@sql.SqlTable::BaseTable(name, alias_opt)) =>
        if alias_opt is None {
          issues.push({
            rule_id: "L003",
            severity: "Warning",
            message: "Table '" +
            name +
            "' is missing an alias. When performing JOIN queries, it is best practice to alias all source tables to avoid column qualification ambiguity.",
          })
        }
      _ => ()
    }

    for join in select.joins {
      match join.table {
        @sql.SqlTable::BaseTable(name, alias_opt) =>
          if alias_opt is None {
            issues.push({
              rule_id: "L003",
              severity: "Warning",
              message: "Joined table '" +
              name +
              "' is missing an alias. All joined tables should have explicit aliases.",
            })
          }
        _ => ()
      }
    }
  }

  // 4. Check for duplicate projection aliases
  let aliases : Map[String, Bool] = Map([])
  for proj in select.projections {
    match proj.alias_name {
      Some(a) =>
        if aliases.get(a).unwrap_or(false) {
          issues.push({
            rule_id: "L004",
            severity: "Error",
            message: "Duplicate projection alias '" +
            a +
            "' detected. Each column alias in a select query must be unique.",
          })
        } else {
          aliases.set(a, true)
        }
      None => ()
    }
  }

  issues
}

///|
pub fn lint_stmt(stmt : @sql.SqlStmt) -> Array[LintIssue] {
  match stmt {
    @sql.SqlStmt::Select(select) => lint_select(select)
    @sql.SqlStmt::Insert(_, select) => lint_select(select)
    @sql.SqlStmt::CreateView(_, select) => lint_select(select)
  }
}
