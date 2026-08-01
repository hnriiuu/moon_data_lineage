///|
pub(all) struct Parser {
  tokens : Array[Token]
  mut pos : Int
} derive(Eq, Debug)

///|
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0 }
}

///|
fn Parser::peek(self : Parser) -> Token {
  if self.pos >= self.tokens.length() {
    Token::EOF
  } else {
    self.tokens[self.pos]
  }
}

///|
fn Parser::advance(self : Parser) -> Token {
  let tok = self.peek()
  self.pos = self.pos + 1
  tok
}

///|
fn Parser::expect_symbol(self : Parser, sym : String) -> Result[Unit, String] {
  match self.peek() {
    Token::Symbol(s) =>
      if s == sym {
        let _ = self.advance()
        Ok(())
      } else {
        Err("Expected symbol '" + sym + "', got '" + s + "'")
      }
    tok => Err("Expected symbol '" + sym + "', got " + debug_to_string(tok))
  }
}

///|
fn Parser::expect_keyword(self : Parser, kw : String) -> Result[Unit, String] {
  match self.peek() {
    Token::Keyword(k) =>
      if k == kw {
        let _ = self.advance()
        Ok(())
      } else {
        Err("Expected keyword '" + kw + "', got '" + k + "'")
      }
    tok => Err("Expected keyword '" + kw + "', got " + debug_to_string(tok))
  }
}

///|
fn debug_to_string(tok : Token) -> String {
  match tok {
    Token::Keyword(k) => "Keyword(" + k + ")"
    Token::Identifier(i) => "Identifier(" + i + ")"
    Token::StringLiteral(s) => "StringLiteral(" + s + ")"
    Token::NumberLiteral(n) => "NumberLiteral(" + n + ")"
    Token::Symbol(s) => "Symbol(" + s + ")"
    Token::EOF => "EOF"
  }
}

///|
fn parse_int_literal(s : String) -> Result[Int, String] {
  let mut val = 0
  for c in s {
    if c >= '0' && c <= '9' {
      val = val * 10 + (c.to_int() - '0'.to_int())
    } else {
      return Err("Invalid character in integer: " + s)
    }
  }
  Ok(val)
}

///|
pub fn Parser::parse_stmt(self : Parser) -> Result[SqlStmt, String] {
  match self.peek() {
    Token::Keyword("SELECT") =>
      match self.parse_select() {
        Ok(select) => Ok(SqlStmt::Select(select))
        Err(e) => Err(e)
      }
    Token::Keyword("INSERT") => {
      let _ = self.advance() // Consume INSERT
      match self.expect_keyword("INTO") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let target_table = match self.advance() {
        Token::Identifier(id) => id
        tok =>
          return Err(
            "Expected identifier for target table in INSERT INTO, got " +
            debug_to_string(tok),
          )
      }
      match self.parse_select() {
        Ok(select) => Ok(SqlStmt::Insert(target_table, select))
        Err(e) => Err(e)
      }
    }
    Token::Keyword("CREATE") => {
      let _ = self.advance() // Consume CREATE
      match self.expect_keyword("VIEW") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let view_name = match self.advance() {
        Token::Identifier(id) => id
        tok =>
          return Err(
            "Expected identifier for view name in CREATE VIEW, got " +
            debug_to_string(tok),
          )
      }
      match self.expect_keyword("AS") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match self.parse_select() {
        Ok(select) => Ok(SqlStmt::CreateView(view_name, select))
        Err(e) => Err(e)
      }
    }
    tok => Err("Unsupported start of statement: " + debug_to_string(tok))
  }
}

///|
fn Parser::parse_select(self : Parser) -> Result[SqlSelect, String] {
  match self.expect_keyword("SELECT") {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  let projections = []
  // Parse projection list
  let mut parse_more = true
  while parse_more {
    match self.parse_projection() {
      Ok(proj) => projections.push(proj)
      Err(e) => return Err(e)
    }

    match self.peek() {
      Token::Symbol(",") => {
        let _ = self.advance() // Consume comma
        ()
      }
      _ => parse_more = false
    }
  }

  let mut from_table : SqlTable? = None
  let joins = []

  // Parse FROM clause if present
  match self.peek() {
    Token::Keyword("FROM") => {
      let _ = self.advance() // Consume FROM
      match self.parse_table() {
        Ok(table) => from_table = Some(table)
        Err(e) => return Err(e)
      }

      // Parse optional JOINs
      while true {
        match self.peek() {
          Token::Keyword("JOIN")
          | Token::Keyword("INNER")
          | Token::Keyword("LEFT")
          | Token::Keyword("RIGHT")
          | Token::Keyword("CROSS") =>
            match self.parse_join() {
              Ok(join) => joins.push(join)
              Err(e) => return Err(e)
            }
          _ => break
        }
      }
    }
    _ => ()
  }

  let mut where_clause : SqlExpr? = None
  match self.peek() {
    Token::Keyword("WHERE") => {
      let _ = self.advance() // Consume WHERE
      match self.parse_expr() {
        Ok(expr) => where_clause = Some(expr)
        Err(e) => return Err(e)
      }
    }
    _ => ()
  }

  // Parse optional GROUP BY
  let group_by = []
  match self.peek() {
    Token::Keyword("GROUP") => {
      let _ = self.advance()
      match self.expect_keyword("BY") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let mut parse_more = true
      while parse_more {
        match self.parse_expr() {
          Ok(expr) => group_by.push(expr)
          Err(e) => return Err(e)
        }
        match self.peek() {
          Token::Symbol(",") => {
            let _ = self.advance()
            ()
          }
          _ => parse_more = false
        }
      }
    }
    _ => ()
  }

  // Parse optional ORDER BY
  let order_by = []
  match self.peek() {
    Token::Keyword("ORDER") => {
      let _ = self.advance()
      match self.expect_keyword("BY") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let mut parse_more = true
      while parse_more {
        let expr = match self.parse_expr() {
          Ok(e) => e
          Err(e) => return Err(e)
        }
        let mut is_desc = false
        match self.peek() {
          Token::Keyword("ASC") => {
            let _ = self.advance()
            ()
          }
          Token::Keyword("DESC") => {
            let _ = self.advance()
            is_desc = true
          }
          _ => ()
        }
        order_by.push((expr, is_desc))
        match self.peek() {
          Token::Symbol(",") => {
            let _ = self.advance()
            ()
          }
          _ => parse_more = false
        }
      }
    }
    _ => ()
  }

  // Parse optional LIMIT
  let mut limit : Int? = None
  match self.peek() {
    Token::Keyword("LIMIT") => {
      let _ = self.advance()
      match self.advance() {
        Token::NumberLiteral(n) =>
          match parse_int_literal(n) {
            Ok(val) => limit = Some(val)
            Err(e) => return Err(e)
          }
        tok =>
          return Err(
            "Expected integer limit value, got " + debug_to_string(tok),
          )
      }
    }
    _ => ()
  }

  Ok({ projections, from_table, joins, where_clause, group_by, order_by, limit })
}

///|
fn Parser::parse_projection(self : Parser) -> Result[SqlProjection, String] {
  let expr = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  let mut alias_name : String? = None

  match self.peek() {
    Token::Keyword("AS") => {
      let _ = self.advance() // Consume AS
      match self.advance() {
        Token::Identifier(id) => alias_name = Some(id)
        tok =>
          return Err(
            "Expected identifier after AS, got " + debug_to_string(tok),
          )
      }
    }
    Token::Identifier(id) => {
      // Implicit alias (e.g., column alias_name)
      let _ = self.advance()
      alias_name = Some(id)
    }
    _ => ()
  }

  Ok({ expr, alias_name })
}

///|
fn get_precedence(op : String) -> Int {
  match op {
    "=" => 1
    "+" | "-" => 2
    "*" | "/" => 3
    _ => 0
  }
}

///|
fn Parser::parse_expr(self : Parser) -> Result[SqlExpr, String] {
  match self.parse_primary() {
    Ok(left) => self.parse_binary_expr(left, 0)
    Err(e) => Err(e)
  }
}

///|
fn Parser::parse_binary_expr(
  self : Parser,
  left : SqlExpr,
  min_precedence : Int,
) -> Result[SqlExpr, String] {
  let mut lhs = left
  while true {
    let op = match self.peek() {
      Token::Symbol(sym) =>
        if sym == "=" || sym == "+" || sym == "-" || sym == "*" || sym == "/" {
          sym
        } else {
          break
        }
      _ => break
    }

    let precedence = get_precedence(op)
    if precedence < min_precedence {
      break
    }

    let _ = self.advance() // Consume op
    let mut rhs = match self.parse_primary() {
      Ok(r) => r
      Err(e) => return Err(e)
    }

    while true {
      let next_op = match self.peek() {
        Token::Symbol(sym) =>
          if sym == "=" || sym == "+" || sym == "-" || sym == "*" || sym == "/" {
            sym
          } else {
            break
          }
        _ => break
      }
      let next_precedence = get_precedence(next_op)
      if next_precedence > precedence {
        match self.parse_binary_expr(rhs, next_precedence) {
          Ok(r) => rhs = r
          Err(e) => return Err(e)
        }
      } else {
        break
      }
    }

    lhs = SqlExpr::BinaryOp(lhs, op, rhs)
  }
  Ok(lhs)
}

///|
fn Parser::parse_primary(self : Parser) -> Result[SqlExpr, String] {
  match self.advance() {
    Token::Symbol("(") => {
      let expr = match self.parse_expr() {
        Ok(e) => e
        Err(e) => return Err(e)
      }
      match self.expect_symbol(")") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      Ok(expr)
    }
    Token::Symbol("*") => Ok(SqlExpr::Star)
    Token::Identifier(id) =>
      // Check if it is table.column or a function call
      match self.peek() {
        Token::Symbol(".") => {
          let _ = self.advance() // Consume dot
          match self.advance() {
            Token::Identifier(col) => Ok(SqlExpr::ColRef(Some(id), col))
            Token::Symbol("*") => Ok(SqlExpr::ColRef(Some(id), "*"))
            tok =>
              Err(
                "Expected column name or * after '.', got " +
                debug_to_string(tok),
              )
          }
        }
        Token::Symbol("(") => {
          let _ = self.advance() // Consume '('
          let args = []
          if self.peek() != Token::Symbol(")") {
            let mut parse_more = true
            while parse_more {
              match self.parse_expr() {
                Ok(arg) => args.push(arg)
                Err(e) => return Err(e)
              }
              match self.peek() {
                Token::Symbol(",") => {
                  let _ = self.advance()
                  ()
                }
                _ => parse_more = false
              }
            }
          }
          match self.expect_symbol(")") {
            Ok(_) => ()
            Err(e) => return Err(e)
          }
          Ok(SqlExpr::FuncCall(id, args))
        }
        _ => Ok(SqlExpr::ColRef(None, id))
      }
    Token::StringLiteral(s) => Ok(SqlExpr::StringVal(s))
    Token::NumberLiteral(n) => Ok(SqlExpr::Number(n))
    tok => Err("Expected expression primary, got " + debug_to_string(tok))
  }
}

///|
fn Parser::parse_table(self : Parser) -> Result[SqlTable, String] {
  match self.peek() {
    Token::Symbol("(") => {
      let _ = self.advance() // Consume (
      let subquery = match self.parse_select() {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      match self.expect_symbol(")") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match self.expect_keyword("AS") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      let alias_name = match self.advance() {
        Token::Identifier(id) => id
        tok =>
          return Err(
            "Expected identifier for subquery alias, got " +
            debug_to_string(tok),
          )
      }
      Ok(SqlTable::Subquery(subquery, alias_name))
    }
    Token::Identifier(name) => {
      let _ = self.advance() // Consume table name
      let mut alias_name : String? = None
      match self.peek() {
        Token::Keyword("AS") => {
          let _ = self.advance()
          match self.advance() {
            Token::Identifier(id) => alias_name = Some(id)
            tok =>
              return Err(
                "Expected identifier after AS, got " + debug_to_string(tok),
              )
          }
        }
        Token::Identifier(id) => {
          // Implicit alias
          let _ = self.advance()
          alias_name = Some(id)
        }
        _ => ()
      }
      Ok(SqlTable::BaseTable(name, alias_name))
    }
    tok => Err("Expected table source, got " + debug_to_string(tok))
  }
}

///|
fn Parser::parse_join(self : Parser) -> Result[SqlJoin, String] {
  let mut join_type = "INNER"
  match self.advance() {
    Token::Keyword("JOIN") => ()
    Token::Keyword("INNER") =>
      match self.expect_keyword("JOIN") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    Token::Keyword("LEFT") => {
      match self.expect_keyword("JOIN") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      join_type = "LEFT"
    }
    Token::Keyword("RIGHT") => {
      match self.expect_keyword("JOIN") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      join_type = "RIGHT"
    }
    Token::Keyword("CROSS") => {
      match self.expect_keyword("JOIN") {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      join_type = "CROSS"
    }
    tok => return Err("Expected JOIN statement, got " + debug_to_string(tok))
  }

  let table = match self.parse_table() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let mut on_expr : SqlExpr? = None

  if join_type != "CROSS" {
    match self.peek() {
      Token::Keyword("ON") => {
        let _ = self.advance()
        let expr = match self.parse_expr() {
          Ok(e) => e
          Err(e) => return Err(e)
        }
        on_expr = Some(expr)
      }
      _ => ()
    }
  }

  Ok({ table, join_type, on_expr })
}
