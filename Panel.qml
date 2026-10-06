import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Promptic panel: the library tree on the left, the fill-in form for the
// selected prompt on the right. Passive mirror of the host; all state lives
// in host.store.
Panel {
  id: root
  moduleName: "io.github.hpolthof.promptic"

  property Item anchorItem: null
  property var host: null
  readonly property var barIdentity: host || root

  readonly property var store: host && host.store ? host.store : null
  readonly property var nodes: store ? store.nodes : []
  readonly property color foreground: bar ? bar.foreground : Color.foreground

  readonly property bool modalOpen: promptDialog.opened || picker.opened || confirm.opened

  readonly property string metaLine: {
    var c = Model.counts(nodes)
    return c.prompts + (c.prompts === 1 ? " prompt" : " prompts") + " · " + c.folders + (c.folders === 1 ? " folder" : " folders")
  }

  property string pendingDeleteId: ""
  property string pickKey: ""

  function open() {
    root.controller.show()
    Qt.callLater(root.restoreFocus)
  }

  function close() {
    root.controller.hide()
  }

  function restoreFocus() {
    if (!root.opened) return
    if (promptDialog.opened) promptDialog.forceActiveFocus()
    else if (picker.opened) picker.forceActiveFocus()
    else tree.takeFocus()
  }

  function askDelete(id) {
    var n = Model.find(root.nodes, id)
    if (!n) return
    var gone = Model.subtreeIds(root.nodes, id).length - 1
    root.pendingDeleteId = id
    confirm.message = n.type === "folder"
      ? "Delete the folder “" + n.name + "”" + (gone > 0 ? " and the " + gone + (gone === 1 ? " item" : " items") + " in it" : "") + "? This cannot be undone."
      : "Delete the prompt “" + n.name + "”? This cannot be undone."
    confirm.opened = true
  }

  onOpenedChanged: if (opened) Qt.callLater(root.restoreFocus)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened

    focusTarget: tree
    contentWidth: panel.fittedContentWidth(Style.space(1000))
    contentHeight: panel.fittedContentHeight(Style.space(640))

    Item {
      id: keyRoot
      anchors.fill: parent

      // Escape and the shortcut keys are handled by the tree and the dialogs
      // themselves, so the shared catcher stays out of the way.
      PanelKeyCatcher {
        anchors.fill: parent
        blocked: true
      }

      PanelHero {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: "Promptic"
        meta: root.metaLine
        foreground: root.foreground
        iconComponent: Component {
          PrompticIcon {
            size: Style.font.display
            color: Color.accent
          }
        }
        trailingControl: Component {
          Row {
            spacing: Style.spacing.xs
            PanelActionButton {
              iconText: Model.GLYPH.folderPlus
              tooltipText: "New folder (Shift+N)"
              foreground: root.foreground
              onClicked: tree.newFolder()
            }
            PanelActionButton {
              iconText: Model.GLYPH.plus
              tooltipText: "New prompt (n)"
              foreground: root.foreground
              onClicked: promptDialog.openNew(tree.targetFolder())
            }
          }
        }
      }

      PanelSeparator {
        id: headerRule
        anchors.top: header.bottom
        anchors.topMargin: Style.spacing.rowGap
        foreground: root.foreground
      }

      Item {
        id: body
        anchors.top: headerRule.bottom
        anchors.topMargin: Style.spacing.panelGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        readonly property real treeWidth: Math.round(Math.min(Style.space(300), width * 0.34))
        readonly property real gap: Style.spacing.panelGap * 2

        LibraryTree {
          id: tree
          x: 0
          width: body.treeWidth
          height: parent.height
          host: root.host
          foreground: root.foreground
          onCloseRequested: root.close()
          onPromptEditRequested: function(id) { promptDialog.openEdit(id) }
          onNewPromptRequested: function(parentId) { promptDialog.openNew(parentId) }
          onDeleteRequested: function(id) { root.askDelete(id) }
          onCopyRequested: use.copy()
        }

        PanelSeparator {
          x: body.treeWidth + body.gap / 2
          width: 1
          height: parent.height
          foreground: root.foreground
          strength: 0.12
        }

        UsePane {
          id: use
          x: body.treeWidth + body.gap
          width: parent.width - x
          height: parent.height
          host: root.host
          nodes: root.nodes
          prompt: {
            var n = tree.selected
            return n && n.type === "prompt" ? n : null
          }
          foreground: root.foreground
          onEditRequested: function(id) { promptDialog.openEdit(id) }
          onBrowseRequested: function(key, mode, current) { root.pickKey = key; picker.show(mode, current) }
          onCopyRequested: use.copy()
          onEscapePressed: tree.takeFocus()
        }
      }

      PromptDialog {
        id: promptDialog
        anchors.fill: parent
        z: 10
        host: root.host
        foreground: root.foreground
        onSaved: function(id) { tree.selectedId = id; Qt.callLater(root.restoreFocus) }
        onClosed: Qt.callLater(root.restoreFocus)
        onOpenedChanged: if (!opened) Qt.callLater(root.restoreFocus)
      }

      FilePicker {
        id: picker
        anchors.fill: parent
        z: 11
        foreground: root.foreground
        onPicked: function(path) { use.setValue(root.pickKey, path); Qt.callLater(root.restoreFocus) }
        onCanceled: { opened = false; Qt.callLater(root.restoreFocus) }
      }

      ConfirmDialog {
        id: confirm
        anchors.fill: parent
        z: 12
        cancelText: "Cancel"
        confirmText: "Delete"
        onOpenedChanged: if (opened) { selectedIndex = 0; forceActiveFocus() }
        onCanceled: { opened = false; Qt.callLater(root.restoreFocus) }
        onConfirmed: {
          opened = false
          if (root.store && root.pendingDeleteId !== "") root.store.remove(root.pendingDeleteId)
          root.pendingDeleteId = ""
          Qt.callLater(root.restoreFocus)
        }
        Keys.onPressed: function(event) { if (confirm.handleKey(event)) event.accepted = true }
      }
    }
  }
}
