import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Persistent library for Promptic: one flat list of folder/prompt nodes in
// library.json. Several instances (one per monitor) share the file; they
// only write in response to a user action, never as a consequence of loading.
Item {
  id: root
  visible: false

  property bool loaded: false
  property var nodes: Model.SEED.map(function(n) { return Object.assign({}, n) })
  property string saveState: "saved"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string dataDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/omarchy/promptic"
  readonly property string libraryPath: dataDir + "/library.json"

  property bool _dirReady: false
  property var _recent: []   // texts this instance wrote recently (echo filter)

  function _find(id) { return Model.find(root.nodes, id) }
  function _copy(o) { return Object.assign({}, o) }

  function _commit(next) {
    root.nodes = next
    var text = Model.libraryJson(next)
    var r = root._recent.slice(-5)
    r.push(text)
    root._recent = r
    root.saveState = "pending"
    if (root._dirReady) libraryFile.setText(text)
    else root._pendingText = text
  }
  property string _pendingText: ""

  on_DirReadyChanged: if (_dirReady && _pendingText !== "") { libraryFile.setText(_pendingText); _pendingText = "" }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.dataDir]
    running: true
    onRunningChanged: if (!running) root._dirReady = true
  }

  FileView {
    id: libraryFile
    path: root.libraryPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      var t = text()
      if (root.loaded && root._recent.indexOf(t) >= 0) return
      var norm = Model.normalizeLibrary(Model.parseJson(t, null))
      if (norm) root.nodes = norm
      else if (String(t).trim() !== "") console.warn("[promptic] library.json is not usable; showing the example library (file kept until the next change)")
      root.loaded = true
    }
    // A missing file is the first run: show the example library, write nothing.
    onLoadFailed: function(error) { root.loaded = true }
    onFileChanged: reload()
    onSaved: root.saveState = "saved"
    onSaveFailed: function(error) {
      console.warn("[promptic] could not save library: " + error)
      root.saveState = "error"
    }
  }

  // ------------------------------------------------------------ operations

  function _newId() {
    return Model.makeId(Date.now(), root.nodes.map(function(n) { return n.id }))
  }

  // Returns the new id.
  function addFolder(parentId, name) {
    var id = root._newId()
    var next = root.nodes.slice()
    next.push({ id: id, type: "folder", parentId: parentId || "", name: String(name), content: "", expanded: false })
    // Show the new folder: open its parent.
    root._commit(root._withExpanded(next, parentId, true))
    return id
  }

  function addPrompt(parentId, name, content) {
    var id = root._newId()
    var next = root.nodes.slice()
    next.push({ id: id, type: "prompt", parentId: parentId || "", name: String(name), content: String(content), expanded: false })
    root._commit(root._withExpanded(next, parentId, true))
    return id
  }

  function _withExpanded(list, id, value) {
    if (!id) return list
    return list.map(function(n) {
      if (n.id !== id || n.expanded === value) return n
      var c = root._copy(n); c.expanded = value; return c
    })
  }

  function setExpanded(id, value) { root._commit(root._withExpanded(root.nodes, id, value)) }

  function rename(id, name) {
    var nm = String(name).trim()
    if (nm === "") return
    root._commit(root.nodes.map(function(n) {
      if (n.id !== id || n.name === nm) return n
      var c = root._copy(n); c.name = nm; return c
    }))
  }

  // patch: any of name, content, parentId (folders cannot move into themselves).
  function updatePrompt(id, patch) {
    var blocked = Model.subtreeIds(root.nodes, id)
    root._commit(root.nodes.map(function(n) {
      if (n.id !== id) return n
      var c = root._copy(n)
      if (patch.name !== undefined && String(patch.name).trim() !== "") c.name = String(patch.name).trim()
      if (patch.content !== undefined && n.type === "prompt") c.content = String(patch.content)
      if (patch.parentId !== undefined && blocked.indexOf(patch.parentId) < 0) c.parentId = String(patch.parentId)
      return c
    }))
  }

  // Removes the node and everything below it.
  function remove(id) {
    var gone = Model.subtreeIds(root.nodes, id)
    root._commit(root.nodes.filter(function(n) { return gone.indexOf(n.id) < 0 }))
  }
}
