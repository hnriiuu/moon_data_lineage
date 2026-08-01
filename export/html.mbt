///|
pub fn export_html_dashboard(graph : @core.LineageGraph) -> String {
  let sb = StringBuilder::new()

  // Build datasets JSON-like metadata to embed in JS if needed
  let datasets_rows = StringBuilder::new()
  for id, ds in graph.datasets {
    let desc = if ds.description != "" {
      ds.description
    } else {
      "No description provided."
    }
    datasets_rows.write_string("<tr>\n")
    datasets_rows.write_string("  <td><strong>" + id + "</strong></td>\n")
    datasets_rows.write_string(
      "  <td><span class=\"badge badge-" +
      ds.dataset_type +
      "\">" +
      ds.dataset_type +
      "</span></td>\n",
    )
    datasets_rows.write_string("  <td>" + desc + "</td>\n")
    datasets_rows.write_string("  <td><code>" + ds.location + "</code></td>\n")
    datasets_rows.write_string("  <td>v" + ds.version + "</td>\n")
    datasets_rows.write_string("</tr>\n")
  }

  let field_deps_rows = StringBuilder::new()
  for target_id, deps in graph.field_dependencies {
    for dep in deps {
      let sources = dep.source_fields.iter().join("<br> ")
      let expr_str = if dep.expression != "" { dep.expression } else { "-" }
      field_deps_rows.write_string("<tr>\n")
      field_deps_rows.write_string(
        "  <td><code>" + target_id + "." + dep.target_field + "</code></td>\n",
      )
      field_deps_rows.write_string("  <td><code>" + sources + "</code></td>\n")
      field_deps_rows.write_string("  <td><code>" + expr_str + "</code></td>\n")
      field_deps_rows.write_string("</tr>\n")
    }
  }

  let mermaid_ds = export_mermaid_dataset_level(graph)
  let mermaid_fd = export_mermaid_field_level(graph)

  sb.write_string("<!DOCTYPE html>\n")
  sb.write_string("<html lang=\"en\">\n")
  sb.write_string("<head>\n")
  sb.write_string("  <meta charset=\"UTF-8\">\n")
  sb.write_string(
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n",
  )
  sb.write_string("  <title>MoonBit Data Lineage Dashboard</title>\n")
  sb.write_string("  <style>\n")
  sb.write_string("    :root {\n")
  sb.write_string("      --bg-color: #0f172a;\n")
  sb.write_string("      --sidebar-bg: #1e293b;\n")
  sb.write_string("      --card-bg: rgba(30, 41, 59, 0.7);\n")
  sb.write_string("      --text-color: #f1f5f9;\n")
  sb.write_string("      --text-muted: #94a3b8;\n")
  sb.write_string("      --accent-color: #38bdf8;\n")
  sb.write_string("      --accent-hover: #0ea5e9;\n")
  sb.write_string("      --border-color: #334155;\n")
  sb.write_string("      --success: #10b981;\n")
  sb.write_string("      --warning: #f59e0b;\n")
  sb.write_string("      --danger: #ef4444;\n")
  sb.write_string("    }\n")
  sb.write_string("    * { box-sizing: border-box; margin: 0; padding: 0; }\n")
  sb.write_string("    body {\n")
  sb.write_string("      font-family: system-ui, -apple-system, sans-serif;\n")
  sb.write_string("      background-color: var(--bg-color);\n")
  sb.write_string("      color: var(--text-color);\n")
  sb.write_string("      display: flex;\n")
  sb.write_string("      min-height: 100vh;\n")
  sb.write_string("      overflow-x: hidden;\n")
  sb.write_string("    }\n")
  sb.write_string("    .sidebar {\n")
  sb.write_string("      width: 260px;\n")
  sb.write_string("      background-color: var(--sidebar-bg);\n")
  sb.write_string("      border-right: 1px solid var(--border-color);\n")
  sb.write_string("      padding: 2rem 1.5rem;\n")
  sb.write_string("      display: flex;\n")
  sb.write_string("      flex-direction: column;\n")
  sb.write_string("      gap: 2rem;\n")
  sb.write_string("    }\n")
  sb.write_string("    .logo {\n")
  sb.write_string("      font-size: 1.25rem;\n")
  sb.write_string("      font-weight: 700;\n")
  sb.write_string("      letter-spacing: -0.025em;\n")
  sb.write_string(
    "      background: linear-gradient(to right, #38bdf8, #818cf8);\n",
  )
  sb.write_string("      -webkit-background-clip: text;\n")
  sb.write_string("      -webkit-text-fill-color: transparent;\n")
  sb.write_string("    }\n")
  sb.write_string("    .menu {\n")
  sb.write_string("      list-style: none;\n")
  sb.write_string("      display: flex;\n")
  sb.write_string("      flex-direction: column;\n")
  sb.write_string("      gap: 0.5rem;\n")
  sb.write_string("    }\n")
  sb.write_string("    .menu-item {\n")
  sb.write_string("      padding: 0.75rem 1rem;\n")
  sb.write_string("      border-radius: 0.375rem;\n")
  sb.write_string("      cursor: pointer;\n")
  sb.write_string("      color: var(--text-muted);\n")
  sb.write_string("      font-weight: 500;\n")
  sb.write_string("      transition: all 0.2s;\n")
  sb.write_string("    }\n")
  sb.write_string("    .menu-item:hover, .menu-item.active {\n")
  sb.write_string("      background-color: var(--border-color);\n")
  sb.write_string("      color: var(--text-color);\n")
  sb.write_string("    }\n")
  sb.write_string("    .main-content {\n")
  sb.write_string("      flex: 1;\n")
  sb.write_string("      padding: 3rem;\n")
  sb.write_string("      overflow-y: auto;\n")
  sb.write_string("    }\n")
  sb.write_string("    .header {\n")
  sb.write_string("      margin-bottom: 2rem;\n")
  sb.write_string("      display: flex;\n")
  sb.write_string("      justify-content: space-between;\n")
  sb.write_string("      align-items: center;\n")
  sb.write_string("    }\n")
  sb.write_string("    .header h1 { font-size: 2rem; font-weight: 800; }\n")
  sb.write_string("    .card {\n")
  sb.write_string("      background-color: var(--card-bg);\n")
  sb.write_string("      border: 1px solid var(--border-color);\n")
  sb.write_string("      border-radius: 0.75rem;\n")
  sb.write_string("      padding: 2rem;\n")
  sb.write_string("      margin-bottom: 2rem;\n")
  sb.write_string("      backdrop-filter: blur(12px);\n")
  sb.write_string("    }\n")
  sb.write_string(
    "    .card h2 { margin-bottom: 1.5rem; font-size: 1.5rem; }\n",
  )
  sb.write_string("    table {\n")
  sb.write_string("      width: 100%;\n")
  sb.write_string("      border-collapse: collapse;\n")
  sb.write_string("      margin-top: 1rem;\n")
  sb.write_string("    }\n")
  sb.write_string("    th, td {\n")
  sb.write_string("      padding: 1rem;\n")
  sb.write_string("      text-align: left;\n")
  sb.write_string("      border-bottom: 1px solid var(--border-color);\n")
  sb.write_string("    }\n")
  sb.write_string("    th {\n")
  sb.write_string("      background-color: rgba(15, 23, 42, 0.5);\n")
  sb.write_string("      color: var(--text-muted);\n")
  sb.write_string("      font-weight: 600;\n")
  sb.write_string("    }\n")
  sb.write_string(
    "    tr:hover { background-color: rgba(255,255,255,0.02); }\n",
  )
  sb.write_string("    .badge {\n")
  sb.write_string("      display: inline-block;\n")
  sb.write_string("      padding: 0.25rem 0.5rem;\n")
  sb.write_string("      border-radius: 9999px;\n")
  sb.write_string("      font-size: 0.75rem;\n")
  sb.write_string("      font-weight: 600;\n")
  sb.write_string("      text-transform: uppercase;\n")
  sb.write_string("    }\n")
  sb.write_string(
    "    .badge-source { background-color: rgba(56, 189, 248, 0.2); color: var(--accent-color); }\n",
  )
  sb.write_string(
    "    .badge-derived { background-color: rgba(129, 140, 248, 0.2); color: #818cf8; }\n",
  )
  sb.write_string(
    "    .badge-target { background-color: rgba(16, 185, 129, 0.2); color: var(--success); }\n",
  )
  sb.write_string("    code {\n")
  sb.write_string("      font-family: monospace;\n")
  sb.write_string("      background-color: rgba(15, 23, 42, 0.6);\n")
  sb.write_string("      padding: 0.2rem 0.4rem;\n")
  sb.write_string("      border-radius: 0.25rem;\n")
  sb.write_string("      font-size: 0.9rem;\n")
  sb.write_string("    }\n")
  sb.write_string("    .tab-content { display: none; }\n")
  sb.write_string("    .tab-content.active { display: block; }\n")
  sb.write_string("    .mermaid-container {\n")
  sb.write_string("      background-color: rgba(15,23,42,0.8);\n")
  sb.write_string("      padding: 1.5rem;\n")
  sb.write_string("      border-radius: 0.5rem;\n")
  sb.write_string("      font-family: monospace;\n")
  sb.write_string("      white-space: pre-wrap;\n")
  sb.write_string("      overflow-x: auto;\n")
  sb.write_string("      max-height: 400px;\n")
  sb.write_string("      border: 1px dashed var(--border-color);\n")
  sb.write_string("    }\n")
  sb.write_string("  </style>\n")
  sb.write_string("  <script type=\"module\">\n")
  sb.write_string(
    "    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';\n",
  )
  sb.write_string(
    "    mermaid.initialize({ startOnLoad: true, theme: 'dark' });\n",
  )
  sb.write_string("  </script>\n")
  sb.write_string("</head>\n")
  sb.write_string("<body>\n")
  sb.write_string("  <div class=\"sidebar\">\n")
  sb.write_string("    <div class=\"logo\">MoonBit Lineage</div>\n")
  sb.write_string("    <ul class=\"menu\">\n")
  sb.write_string(
    "      <li class=\"menu-item active\" onclick=\"switchTab('overview')\">Overview</li>\n",
  )
  sb.write_string(
    "      <li class=\"menu-item\" onclick=\"switchTab('datasets')\">Datasets Catalog</li>\n",
  )
  sb.write_string(
    "      <li class=\"menu-item\" onclick=\"switchTab('mappings')\">Column Mappings</li>\n",
  )
  sb.write_string(
    "      <li class=\"menu-item\" onclick=\"switchTab('mermaid')\">Visual Flowchart</li>\n",
  )
  sb.write_string("    </ul>\n")
  sb.write_string("  </div>\n")
  sb.write_string("  <div class=\"main-content\">\n")
  sb.write_string("    <!-- Overview Tab -->\n")
  sb.write_string("    <div id=\"overview\" class=\"tab-content active\">\n")
  sb.write_string("      <div class=\"header\">\n")
  sb.write_string("        <h1>Overview Dashboard</h1>\n")
  sb.write_string("      </div>\n")
  sb.write_string("      <div class=\"card\">\n")
  sb.write_string("        <h2>About Project</h2>\n")
  sb.write_string(
    "        <p>This is a column-level lineage graph generated dynamically by the <strong>moon-data-lineage</strong> tool.</p>\n",
  )
  sb.write_string(
    "        <p style=\"margin-top: 1rem;\">It parses SQL transformation queries, resolves schemas, and visualizes mapping paths and risk profiles.</p>\n",
  )
  sb.write_string("      </div>\n")
  sb.write_string("    </div>\n")
  sb.write_string("    <!-- Datasets Tab -->\n")
  sb.write_string("    <div id=\"datasets\" class=\"tab-content\">\n")
  sb.write_string("      <div class=\"header\">\n")
  sb.write_string("        <h1>Registered Datasets</h1>\n")
  sb.write_string("      </div>\n")
  sb.write_string("      <div class=\"card\">\n")
  sb.write_string("        <h2>Data Catalog</h2>\n")
  sb.write_string("        <table>\n")
  sb.write_string("          <thead>\n")
  sb.write_string("            <tr>\n")
  sb.write_string("              <th>Dataset ID</th>\n")
  sb.write_string("              <th>Type</th>\n")
  sb.write_string("              <th>Description</th>\n")
  sb.write_string("              <th>Storage Location</th>\n")
  sb.write_string("              <th>Version</th>\n")
  sb.write_string("            </tr>\n")
  sb.write_string("          </thead>\n")
  sb.write_string("          <tbody>\n")
  sb.write_string(datasets_rows.to_string())
  sb.write_string("          </tbody>\n")
  sb.write_string("        </table>\n")
  sb.write_string("      </div>\n")
  sb.write_string("    </div>\n")
  sb.write_string("    <!-- Mappings Tab -->\n")
  sb.write_string("    <div id=\"mappings\" class=\"tab-content\">\n")
  sb.write_string("      <div class=\"header\">\n")
  sb.write_string("        <h1>Column Mappings</h1>\n")
  sb.write_string("      </div>\n")
  sb.write_string("      <div class=\"card\">\n")
  sb.write_string("        <h2>Impact Analysis Rules</h2>\n")
  sb.write_string("        <table>\n")
  sb.write_string("          <thead>\n")
  sb.write_string("            <tr>\n")
  sb.write_string("              <th>Target Column</th>\n")
  sb.write_string("              <th>Source Column(s)</th>\n")
  sb.write_string("              <th>Transformation Expression</th>\n")
  sb.write_string("            </tr>\n")
  sb.write_string("          </thead>\n")
  sb.write_string("          <tbody>\n")
  sb.write_string(field_deps_rows.to_string())
  sb.write_string("          </tbody>\n")
  sb.write_string("        </table>\n")
  sb.write_string("      </div>\n")
  sb.write_string("    </div>\n")
  sb.write_string("    <!-- Mermaid Visual Tab -->\n")
  sb.write_string("    <div id=\"mermaid\" class=\"tab-content\">\n")
  sb.write_string("      <div class=\"header\">\n")
  sb.write_string("        <h1>Visual Flowcharts</h1>\n")
  sb.write_string("      </div>\n")
  sb.write_string("      <div class=\"card\">\n")
  sb.write_string("        <h2>Dataset-Level Lineage</h2>\n")
  sb.write_string("        <div class=\"mermaid\">\n")
  sb.write_string(mermaid_ds)
  sb.write_string("        </div>\n")
  sb.write_string("      </div>\n")
  sb.write_string("      <div class=\"card\">\n")
  sb.write_string("        <h2>Mermaid Syntax (Field-Level)</h2>\n")
  sb.write_string("        <div class=\"mermaid-container\">")
  sb.write_string(mermaid_fd)
  sb.write_string("</div>\n")
  sb.write_string("      </div>\n")
  sb.write_string("    </div>\n")
  sb.write_string("  </div>\n")
  sb.write_string("  <script>\n")
  sb.write_string("    function switchTab(tabId) {\n")
  sb.write_string(
    "      document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));\n",
  )
  sb.write_string(
    "      document.querySelectorAll('.menu-item').forEach(el => el.classList.remove('active'));\n",
  )
  sb.write_string(
    "      document.getElementById(tabId).classList.add('active');\n",
  )
  sb.write_string("      event.currentTarget.classList.add('active');\n")
  sb.write_string("    }\n")
  sb.write_string("  </script>\n")
  sb.write_string("</body>\n")
  sb.write_string("</html>\n")

  sb.to_string()
}
