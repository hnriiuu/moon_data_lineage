///|
pub(all) enum SqlExpr {
  ColRef(String?, String) // table/alias_name, column name
  Star
  Number(String)
  StringVal(String)
  BinaryOp(SqlExpr, String, SqlExpr) // e.g. a + b
  FuncCall(String, Array[SqlExpr]) // e.g. COUNT(x)
} derive(Eq, Debug)

///|
pub(all) struct SqlProjection {
  expr : SqlExpr
  alias_name : String?
} derive(Eq, Debug)

///|
pub(all) enum SqlTable {
  BaseTable(String, String?) // table_name, alias_name
  Subquery(SqlSelect, String) // subquery, alias_name
} derive(Eq, Debug)

///|
pub(all) struct SqlJoin {
  table : SqlTable
  join_type : String // "INNER", "LEFT", "RIGHT", "CROSS"
  on_expr : SqlExpr?
} derive(Eq, Debug)

///|
pub(all) struct SqlSelect {
  projections : Array[SqlProjection]
  from_table : SqlTable?
  joins : Array[SqlJoin]
  where_clause : SqlExpr?
  group_by : Array[SqlExpr]
  order_by : Array[(SqlExpr, Bool)] // expression, is_desc
  limit : Int?
} derive(Eq, Debug)

///|
pub(all) enum SqlStmt {
  Select(SqlSelect)
  Insert(String, SqlSelect) // target_table, select_statement
  CreateView(String, SqlSelect) // view_name, select_statement
} derive(Eq, Debug)
