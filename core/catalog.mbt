///|
/// Represents a single column metadata entry in the Data Catalog.
/// Includes the dataset reference, name, type, description, semantic tags,
/// and whether the column contains personally identifiable information (PII).
pub(all) struct CatalogEntry {
  dataset_id : String
  field_name : String
  data_type : String
  description : String
  tags : Array[String]
  is_pii : Bool
} derive(Eq, Debug)

///|
/// A central repository mapping all column metadata inside the lineage graph.
/// Tracks catalog entries and keeps an index of PII-marked columns.
pub(all) struct DataCatalog {
  entries : Map[String, CatalogEntry]
  pii_columns : Array[String]
} derive(Eq, Debug)

///|
/// Creates a new empty `DataCatalog` metadata store.
pub fn DataCatalog::new() -> DataCatalog {
  { entries: Map([]), pii_columns: [] }
}

///|
/// Scans the given lineage graph to build a comprehensive data catalog.
/// Identifies and catalogs every field in every dataset, checking tags
/// to mark sensitive columns automatically.
pub fn build_catalog(graph : LineageGraph) -> DataCatalog {
  let entries : Map[String, CatalogEntry] = Map([])
  let pii_columns = []

  for ds_id, ds in graph.datasets {
    for f in ds.schema {
      let key = ds_id + "." + f.name
      let mut is_pii = false
      for tag in f.tags {
        if tag.to_lower() == "pii" || tag.to_lower() == "sensitive" {
          is_pii = true
          break
        }
      }

      let entry = {
        dataset_id: ds_id,
        field_name: f.name,
        data_type: f.data_type,
        description: f.description,
        tags: f.tags.copy(),
        is_pii,
      }
      entries.set(key, entry)
      if is_pii {
        pii_columns.push(key)
      }
    }
  }

  { entries, pii_columns }
}

///|
/// Traces downstream flow of PII data. Any column downstream of a PII column is flagged.
/// Returns list of downstream columns in format "dataset.field" that inherit PII sensitivity.
/// This acts as a vital auditing check for compliance frameworks (e.g. GDPR).
pub fn trace_pii_propagation(
  graph : LineageGraph,
  catalog : DataCatalog,
) -> Array[String] {
  let propagated = []
  let visited : Map[String, Bool] = Map([])

  // Internal DFS helper
  fn dfs_pii(node : String) {
    visited.set(node, true)

    // Find all field dependencies where 'node' is a source field
    for target_id, deps in graph.field_dependencies {
      for dep in deps {
        if dep.source_fields.contains(node) {
          let target_key = target_id + "." + dep.target_field
          if visited.get(target_key).unwrap_or(false) == false {
            if propagated.contains(target_key) == false {
              propagated.push(target_key)
            }
            dfs_pii(target_key)
          }
        }
      }
    }
  }

  for pii_col in catalog.pii_columns {
    dfs_pii(pii_col)
  }

  propagated
}
