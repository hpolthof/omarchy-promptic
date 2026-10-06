.pragma library

// Pure helpers for Promptic: the template language and the folder tree.
// No QML types in here so tests/model_check.mjs can run it under node.

var GLYPH = {
  folder:     "󰉋",
  folderOpen: "󰝰",
  folderPlus: "󰉗",
  prompt:     "󰈙",
  chevronR:   "󰅂",
  chevronD:   "󰅀",
  plus:       "󰐕",
  pencil:     "󰏫",
  rename:     "󰑕",
  trash:      "󰆴",
  copy:       "󰆏",
  check:      "󰄬",
  calendar:   "󰃭",
  close:      "󰅖"
}

var YES = ["yes", "y", "true", "1", "ja"]
var NO = ["no", "n", "false", "0", "nee"]

// ------------------------------------------------------------------ dates

function pad2(n) { return (n < 10 ? "0" : "") + n }

function isoDate(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) }

// "2026-10-06" -> Date (local midnight), or null when it is not a real date.
function parseIso(s) {
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(s || "").trim())
  if (!m) return null
  var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
  return d.getFullYear() === Number(m[1]) && d.getMonth() === Number(m[2]) - 1 && d.getDate() === Number(m[3]) ? d : null
}

// ------------------------------------------------------------- templates
//
//   {{ Label }}                      free text
//   {{ Label || default }}           free text with a default
//   {{ Label | [A,B,C] }}            dropdown
//   {{ Label | yesno }}              Yes / No radio
//   {{ Label | date }}               date picker
//   {{ Label | dir }}                directory path, chosen in a popup
//   {{ Label | file }}               file path, chosen in a popup
//   any of the typed forms also take  || default

function parseField(inner) {
  var def = null
  var spec = inner
  var di = inner.indexOf("||")
  if (di >= 0) {
    spec = inner.slice(0, di)
    def = inner.slice(di + 2).trim()
  }
  var label = spec
  var fmt = ""
  var pi = spec.indexOf("|")
  if (pi >= 0) {
    label = spec.slice(0, pi)
    fmt = spec.slice(pi + 1).trim()
  }
  label = label.trim()
  if (label === "") return null

  var f = { key: label, label: label, type: "text", options: [], def: def }
  var low = fmt.toLowerCase()
  if (low === "yesno") f.type = "yesno"
  else if (low === "date") f.type = "date"
  else if (low === "dir") f.type = "dir"
  else if (low === "file") f.type = "file"
  else if (fmt.charAt(0) === "[" && fmt.charAt(fmt.length - 1) === "]") {
    var opts = fmt.slice(1, -1).split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
    if (opts.length > 0) { f.type = "choice"; f.options = opts }
  }
  return f
}

// Splits a prompt into literal pieces and fields. Fields that share a label
// share one value; the first occurrence decides the type.
//   -> { parts: [string | { key }], fields: [field] }
function parse(text) {
  var src = String(text === undefined || text === null ? "" : text)
  var re = /\{\{([\s\S]*?)\}\}/g
  var parts = []
  var fields = []
  var seen = {}
  var last = 0
  var m
  while ((m = re.exec(src)) !== null) {
    var f = parseField(m[1])
    if (!f) continue
    if (m.index > last) parts.push(src.slice(last, m.index))
    last = m.index + m[0].length
    if (!seen[f.key]) { seen[f.key] = true; fields.push(f) }
    parts.push({ key: f.key })
  }
  if (last < src.length) parts.push(src.slice(last))
  return { parts: parts, fields: fields }
}

function defaultValue(field, today) {
  var d = field.def === null || field.def === undefined ? "" : String(field.def)
  var low = d.toLowerCase()
  if (field.type === "choice") {
    for (var i = 0; i < field.options.length; i++) if (field.options[i] === d) return d
    for (var j = 0; j < field.options.length; j++) if (field.options[j].toLowerCase() === low) return field.options[j]
    return field.options[0]
  }
  if (field.type === "yesno") {
    if (YES.indexOf(low) >= 0) return "Yes"
    if (NO.indexOf(low) >= 0) return "No"
    return ""
  }
  if (field.type === "date") {
    if (low === "today") return isoDate(today || new Date())
    var p = parseIso(d)
    return p ? isoDate(p) : ""
  }
  return d
}

function defaults(fields, today) {
  var out = {}
  for (var i = 0; i < fields.length; i++) out[fields[i].key] = defaultValue(fields[i], today)
  return out
}

function render(parsed, values) {
  var out = ""
  for (var i = 0; i < parsed.parts.length; i++) {
    var p = parsed.parts[i]
    if (typeof p === "string") out += p
    else out += values && values[p.key] !== undefined ? String(values[p.key]) : ""
  }
  return out
}

function emptyCount(fields, values) {
  var n = 0
  for (var i = 0; i < fields.length; i++)
    if (String(values[fields[i].key] === undefined ? "" : values[fields[i].key]).trim() === "") n++
  return n
}

// ------------------------------------------------------------------ tree
//
// The library is a flat list of nodes:
//   { id, type: "folder" | "prompt", parentId ("" = root), name, content, expanded }

function makeId(now, taken) {
  var base = "n" + Number(now).toString(36)
  var id = base
  var i = 1
  while (taken.indexOf(id) >= 0) id = base + "-" + (i++)
  return id
}

function byName(a, b) {
  if (a.type !== b.type) return a.type === "folder" ? -1 : 1
  return String(a.name).toLowerCase() < String(b.name).toLowerCase() ? -1
       : String(a.name).toLowerCase() > String(b.name).toLowerCase() ? 1 : 0
}

function children(nodes, parentId) {
  return nodes.filter(function(n) { return n.parentId === parentId }).sort(byName)
}

function find(nodes, id) {
  for (var i = 0; i < nodes.length; i++) if (nodes[i].id === id) return nodes[i]
  return null
}

// Visible rows in display order, honouring expanded folders.
function rows(nodes) {
  var out = []
  function walk(parentId, depth) {
    var kids = children(nodes, parentId)
    for (var i = 0; i < kids.length; i++) {
      var n = kids[i]
      var hasKids = n.type === "folder" && nodes.some(function(c) { return c.parentId === n.id })
      out.push({ id: n.id, type: n.type, name: n.name, depth: depth, expanded: n.expanded === true, hasChildren: hasKids })
      if (n.type === "folder" && n.expanded === true) walk(n.id, depth + 1)
    }
  }
  walk("", 0)
  return out
}

// id plus every descendant id.
function subtreeIds(nodes, id) {
  var ids = [id]
  for (var i = 0; i < ids.length; i++)
    for (var j = 0; j < nodes.length; j++)
      if (nodes[j].parentId === ids[i] && ids.indexOf(nodes[j].id) < 0) ids.push(nodes[j].id)
  return ids
}

function pathOf(nodes, id) {
  var names = []
  var cur = find(nodes, id)
  var guard = 0
  while (cur && guard++ < 64) {
    names.unshift(cur.name)
    cur = cur.parentId === "" ? null : find(nodes, cur.parentId)
  }
  return names
}

// Folder choices for the "Folder" dropdown, indented by depth. `exclude`
// hides a folder and everything below it (a folder cannot move into itself).
function folderOptions(nodes, exclude) {
  var skip = exclude ? subtreeIds(nodes, exclude) : []
  var out = [{ value: "", label: "Library (top level)" }]
  function walk(parentId, depth) {
    var kids = children(nodes, parentId)
    for (var i = 0; i < kids.length; i++) {
      var n = kids[i]
      if (n.type !== "folder" || skip.indexOf(n.id) >= 0) continue
      out.push({ value: n.id, label: new Array(depth + 2).join("  ") + n.name })
      walk(n.id, depth + 1)
    }
  }
  walk("", 0)
  return out
}

function counts(nodes) {
  var f = 0
  for (var i = 0; i < nodes.length; i++) if (nodes[i].type === "folder") f++
  return { folders: f, prompts: nodes.length - f }
}

function parseJson(text, fallback) {
  try { return JSON.parse(String(text)) } catch (e) { return fallback }
}

// Drops anything malformed, repairs dangling parents and cycles.
function normalizeLibrary(raw) {
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.nodes)) return null
  var out = []
  var ids = {}
  for (var i = 0; i < raw.nodes.length; i++) {
    var n = raw.nodes[i]
    if (!n || typeof n !== "object" || typeof n.id !== "string" || n.id === "" || ids[n.id]) continue
    if (n.type !== "folder" && n.type !== "prompt") continue
    ids[n.id] = true
    out.push({
      id: n.id,
      type: n.type,
      parentId: typeof n.parentId === "string" ? n.parentId : "",
      name: typeof n.name === "string" && n.name.trim() !== "" ? n.name : (n.type === "folder" ? "Folder" : "Prompt"),
      content: n.type === "prompt" && typeof n.content === "string" ? n.content : "",
      expanded: n.type === "folder" && n.expanded === true
    })
  }
  var folderIds = {}
  out.forEach(function(n) { if (n.type === "folder") folderIds[n.id] = true })
  out.forEach(function(n) { if (n.parentId !== "" && !folderIds[n.parentId]) n.parentId = "" })
  // A cycle never reaches the root; lift such nodes to the top level.
  out.forEach(function(n) {
    var cur = n
    var steps = 0
    while (cur && cur.parentId !== "" && steps++ < out.length + 1) cur = find(out, cur.parentId)
    if (steps > out.length) n.parentId = ""
  })
  return out
}

function libraryJson(nodes) {
  return JSON.stringify({ version: 1, nodes: nodes }, null, 2)
}

var SEED = [
  { id: "seed-folder", type: "folder", parentId: "", name: "Getting started", content: "", expanded: true },
  { id: "seed-prompt", type: "prompt", parentId: "seed-folder", name: "Code review",
    content: "Review the {{ Language | [TypeScript,Python,Go,Rust,Other] || Python }} code below for {{ Focus | [bugs,security,performance,readability] }} problems.\n\n" +
             "Project: {{ Project name || My project }}\n" +
             "Review by: {{ Deadline | date }}\n" +
             "Explain the fixes: {{ Explain | yesno || yes }}\n\n" +
             "Code:\n{{ Paste the code here }}\n" }
]
