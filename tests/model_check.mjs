import { readFileSync } from "node:fs"
import assert from "node:assert"
const src = readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(".pragma library", "")
const names = ["parse","defaults","defaultValue","render","emptyCount","rows","subtreeIds","folderOptions","normalizeLibrary","pathOf","isoDate","parseIso","children","counts","SEED"]
const M = new Function(src + "\nreturn {" + names.join(",") + "}")()

const p = M.parse("Hi {{ Name || Sam }}, pick {{ Kies je letter | [A,B,C] || B }}. Awake? {{ Ben je wakker? | yesno }} On {{ Wanneer? | date || today }} {{ Name || other }} {{ }} {{x|[]}}")
assert.deepEqual(p.fields.map(f => [f.key, f.type]), [["Name", "text"], ["Kies je letter", "choice"], ["Ben je wakker?", "yesno"], ["Wanneer?", "date"], ["x", "text"]])
assert.deepEqual(p.fields[1].options, ["A", "B", "C"])
const today = new Date(2026, 9, 6)
const d = M.defaults(p.fields, today)
assert.deepEqual(d, { "Name": "Sam", "Kies je letter": "B", "Ben je wakker?": "", "Wanneer?": "2026-10-06", "x": "" })
assert.equal(M.emptyCount(p.fields, d), 2)
d["Ben je wakker?"] = "Yes"
assert.equal(M.render(p, d), "Hi Sam, pick B. Awake? Yes On 2026-10-06 Sam {{ }} ")
assert.equal(M.defaultValue({ type: "choice", options: ["A", "B"], def: "z" }), "A")
assert.equal(M.defaultValue({ type: "yesno", def: "No" }), "No")
assert.equal(M.parseIso("2026-02-30"), null)
assert.deepEqual(M.parse("{{ A | dir }}{{ B | file || /etc/hosts }}").fields.map(f => [f.type, f.def]), [["dir", null], ["file", "/etc/hosts"]])
assert.equal(M.render(M.parse("no fields"), {}), "no fields")
assert.equal(M.parse("a {{ b || c || d }}").fields[0].def, "c || d")

const nodes = [
  { id: "a", type: "folder", parentId: "", name: "Zed", content: "", expanded: true },
  { id: "b", type: "folder", parentId: "a", name: "Inner", content: "", expanded: false },
  { id: "c", type: "prompt", parentId: "b", name: "Deep", content: "x", expanded: false },
  { id: "d", type: "prompt", parentId: "a", name: "Alpha", content: "x", expanded: false },
  { id: "e", type: "prompt", parentId: "", name: "Root prompt", content: "x", expanded: false }
]
assert.deepEqual(M.rows(nodes).map(r => r.id + "@" + r.depth), ["a@0", "b@1", "d@1", "e@0"])
assert.deepEqual(M.subtreeIds(nodes, "a").sort(), ["a", "b", "c", "d"])
assert.deepEqual(M.pathOf(nodes, "c"), ["Zed", "Inner", "Deep"])
assert.deepEqual(M.folderOptions(nodes, "a").map(o => o.value), [""])
assert.deepEqual(M.folderOptions(nodes).map(o => o.value), ["", "a", "b"])
assert.deepEqual(M.counts(nodes), { folders: 2, prompts: 3 })
const bad = M.normalizeLibrary({ nodes: [{ id: "x", type: "folder", parentId: "y", name: "X" }, { id: "y", type: "folder", parentId: "x", name: "Y" }, { id: "x", type: "prompt" }, { id: "z", type: "prompt", parentId: "gone", name: " " }, null] })
assert.equal(bad.length, 3)
assert.ok(bad.every(n => n.parentId === "" || bad.some(o => o.id === n.parentId)))
assert.equal(bad.find(n => n.id === "z").parentId, "")
assert.equal(M.normalizeLibrary({ nodes: "no" }), null)
assert.ok(M.parse(M.SEED[1].content).fields.length === 6)
console.log("ok")
