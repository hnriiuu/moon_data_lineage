///|
pub(all) enum Token {
  Keyword(String)
  Identifier(String)
  StringLiteral(String)
  NumberLiteral(String)
  Symbol(String)
  EOF
} derive(Eq, Debug)

///|
pub(all) struct Lexer {
  input : String
  len : Int
  mut pos : Int
} derive(Eq, Debug)

///|
pub fn Lexer::new(input : String) -> Lexer {
  { input, len: input.length(), pos: 0 }
}

///|
fn Lexer::peek(self : Lexer) -> Char {
  if self.pos >= self.len {
    '\u{0000}'
  } else {
    self.input[self.pos].to_char().unwrap_or('\u{0000}')
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let c = self.peek()
  self.pos = self.pos + 1
  c
}

///|
fn Lexer::is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn Lexer::is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn Lexer::is_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while self.pos < self.len && Lexer::is_whitespace(self.peek()) {
    let _ = self.advance()
  }
}

///|
fn Lexer::read_identifier(self : Lexer) -> String {
  let start = self.pos
  while self.pos < self.len {
    let c = self.peek()
    if Lexer::is_alpha(c) || Lexer::is_digit(c) {
      let _ = self.advance()
    } else {
      break
    }
  }
  self.input[start:self.pos].to_owned()
}

///|
fn Lexer::read_number(self : Lexer) -> String {
  let start = self.pos
  while self.pos < self.len && Lexer::is_digit(self.peek()) {
    let _ = self.advance()
  }
  if self.pos < self.len && self.peek() == '.' {
    let _ = self.advance()
    while self.pos < self.len && Lexer::is_digit(self.peek()) {
      let _ = self.advance()
    }
  }
  self.input[start:self.pos].to_owned()
}

///|
fn Lexer::read_string(self : Lexer, quote : Char) -> String {
  let _ = self.advance() // Consume start quote
  let start = self.pos
  while self.pos < self.len && self.peek() != quote {
    let _ = self.advance()
  }
  let end = self.pos
  if self.pos < self.len {
    let _ = self.advance() // Consume end quote
  }
  self.input[start:end].to_owned()
}

///|
pub fn Lexer::tokenize(self : Lexer) -> Array[Token] {
  let tokens = []

  while self.pos < self.len {
    self.skip_whitespace()
    if self.pos >= self.len {
      break
    }

    let c = self.peek()

    // Check symbols
    if c == ',' ||
      c == '.' ||
      c == '(' ||
      c == ')' ||
      c == '=' ||
      c == '*' ||
      c == '+' ||
      c == '-' ||
      c == '/' {
      let sym = self.advance().to_string()
      tokens.push(Token::Symbol(sym))
      continue
    }

    // Check strings
    if c == '\'' || c == '"' || c == '`' {
      let val = self.read_string(c)
      tokens.push(Token::StringLiteral(val))
      continue
    }

    // Check numbers
    if Lexer::is_digit(c) {
      let num = self.read_number()
      tokens.push(Token::NumberLiteral(num))
      continue
    }

    // Check identifiers or keywords
    if Lexer::is_alpha(c) {
      let id = self.read_identifier()
      let upper = id.to_upper()
      if upper == "SELECT" ||
        upper == "INSERT" ||
        upper == "INTO" ||
        upper == "FROM" ||
        upper == "JOIN" ||
        upper == "ON" ||
        upper == "AS" ||
        upper == "WHERE" ||
        upper == "AND" ||
        upper == "OR" ||
        upper == "CREATE" ||
        upper == "VIEW" ||
        upper == "TABLE" ||
        upper == "INNER" ||
        upper == "LEFT" ||
        upper == "RIGHT" ||
        upper == "CROSS" ||
        upper == "UNION" {
        tokens.push(Token::Keyword(upper))
      } else {
        tokens.push(Token::Identifier(id))
      }
      continue
    }

    // Unknown character - skip to avoid infinite loop
    let _ = self.advance()
  }

  tokens.push(Token::EOF)
  tokens
}
