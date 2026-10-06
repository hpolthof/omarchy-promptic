import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Left column: the folder tree. Folders and prompts are renamed in place;
// new folders appear as an editable row. Handles its own keys.
Item {
  id: root

  property var host: null
  property color foreground: Color.foreground

  property string selectedId: ""
  property string renamingId: ""
  property bool renamingNew: false

  signal promptEditRequested(string id)
  signal newPromptRequested(string parentId)
  signal deleteRequested(string id)
  signal closeRequested()
  signal copyRequested()

  readonly property var store: host && host.store ? host.store : null
  readonly property var nodes: store ? store.nodes : []
  readonly property var rowList: Model.rows(nodes)
  readonly property var selected: Model.find(nodes, selectedId)
  readonly property bool typing: renamingId !== ""

  readonly property color dim: Qt.darker(foreground, 1.5)

  function takeFocus() { root.forceActiveFocus() }

  // Folder that new things go into: the selected folder, or the folder
  // holding the selected prompt, or the top level.
  function targetFolder() {
    var s = root.selected
    if (!s) return ""
    return s.type === "folder" ? s.id : s.parentId
  }

  function newFolder() {
    if (!root.store) return
    var id = root.store.addFolder(root.targetFolder(), "New folder")
    root.selectedId = id
    root.beginRename(id, true)
  }

  function beginRename(id, isNew) {
    root.selectedId = id
    root.renamingNew = isNew === true
    root.renamingId = id
  }

  function commitRename(name) {
    var id = root.renamingId
    if (id === "") return
    root.renamingId = ""
    root.renamingNew = false
    if (root.store) root.store.rename(id, name)
    root.takeFocus()
  }

  function cancelRename() {
    var id = root.renamingId
    var wasNew = root.renamingNew
    root.renamingId = ""
    root.renamingNew = false
    if (wasNew && root.store) {
      root.store.remove(id)
      root.selectedId = ""
    }
    root.takeFocus()
  }

  function toggle(id) {
    var n = Model.find(root.nodes, id)
    if (n && n.type === "folder" && root.store) root.store.setExpanded(id, !n.expanded)
  }

  function selectIndex(i) {
    if (i < 0 || i >= rowList.length) return
    root.selectedId = rowList[i].id
    Qt.callLater(function() { root.ensureVisible(i) })
  }

  function indexOfSelected() {
    for (var i = 0; i < rowList.length; i++) if (rowList[i].id === selectedId) return i
    return -1
  }

  function ensureVisible(i) {
    var it = rep.itemAt(i)
    if (!it) return
    if (it.y < flick.contentY) flick.contentY = it.y
    else if (it.y + it.height > flick.contentY + flick.height) flick.contentY = it.y + it.height - flick.height
  }

  // The selection can vanish (deleted). A collapsed parent hides it but keeps it.
  onNodesChanged: {
    if (store && selectedId !== "" && !Model.find(nodes, selectedId)) selectedId = ""
  }

  focus: true

  Keys.onPressed: function(event) {
    if (root.typing) return
    var k = event.key
    var t = event.text
    var i = root.indexOfSelected()
    var sel = root.selected
    if (event.modifiers & Qt.ControlModifier) {
      if (k === Qt.Key_Return || k === Qt.Key_Enter) { root.copyRequested(); event.accepted = true }
      return
    }
    if (k === Qt.Key_Escape) root.closeRequested()
    else if (k === Qt.Key_Down || t === "j") root.selectIndex(i < 0 ? 0 : Math.min(rowList.length - 1, i + 1))
    else if (k === Qt.Key_Up || t === "k") root.selectIndex(i < 0 ? 0 : Math.max(0, i - 1))
    else if (k === Qt.Key_Right || t === "l") {
      if (sel && sel.type === "folder" && !sel.expanded) root.toggle(sel.id)
      else if (sel && sel.type === "folder") root.selectIndex(i + 1)
    } else if (k === Qt.Key_Left || t === "h") {
      if (sel && sel.type === "folder" && sel.expanded) root.toggle(sel.id)
      else if (sel && sel.parentId !== "") root.selectedId = sel.parentId
    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      if (sel && sel.type === "folder") root.toggle(sel.id)
    } else if (k === Qt.Key_F2 || t === "r") { if (sel) root.beginRename(sel.id, false) }
    else if (k === Qt.Key_Delete || t === "x") { if (sel) root.deleteRequested(sel.id) }
    else if (t === "e") { if (sel && sel.type === "prompt") root.promptEditRequested(sel.id) }
    else if (t === "n") root.newPromptRequested(root.targetFolder())
    else if (t === "N") root.newFolder()
    else return
    event.accepted = true
  }

  Text {
    visible: root.rowList.length === 0
    anchors.centerIn: parent
    width: parent.width - Style.space(24)
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: "Your library is empty.\nAdd a folder or a prompt with the buttons above."
    color: root.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Flickable {
    id: flick
    anchors.fill: parent
    contentHeight: col.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Clicking the empty area clears the selection (new items go to the top level).
    MouseArea {
      width: flick.width
      height: Math.max(flick.height, col.height)
      onClicked: { root.selectedId = ""; root.takeFocus() }
    }

    Column {
      id: col
      width: flick.width
      spacing: Style.spacing.xxs

      Repeater {
        id: rep
        model: root.rowList

        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index

          readonly property bool isSelected: root.selectedId === modelData.id
          readonly property bool isFolder: modelData.type === "folder"
          readonly property bool renaming: root.renamingId === modelData.id
          readonly property bool showActions: (isSelected || rowHover.hovered) && !renaming

          width: col.width
          height: Style.spacing.controlHeight
          radius: Style.cornerRadius
          color: isSelected ? Style.selectedFillFor(root.foreground, Color.accent)
               : rowHover.hovered ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

          HoverHandler { id: rowHover }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !row.renaming
            onClicked: {
              root.selectedId = row.modelData.id
              if (row.isFolder) root.toggle(row.modelData.id)
              root.takeFocus()
            }
            onDoubleClicked: if (!row.isFolder) root.promptEditRequested(row.modelData.id)
          }

          Text {
            id: chevron
            x: Style.spacing.xs + row.modelData.depth * Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.font.icon
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: row.isFolder ? (row.modelData.expanded ? Model.GLYPH.chevronD : Model.GLYPH.chevronR) : ""
            opacity: row.isFolder && row.modelData.hasChildren ? 0.9 : 0.3
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            id: icon
            anchors.left: chevron.right
            anchors.leftMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: row.isFolder ? (row.modelData.expanded ? Model.GLYPH.folderOpen : Model.GLYPH.folder) : Model.GLYPH.prompt
            color: row.isFolder ? Color.accent : root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
          }

          Text {
            visible: !row.renaming
            anchors.left: icon.right
            anchors.leftMargin: Style.spacing.controlGap
            anchors.right: actions.left
            anchors.rightMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: row.modelData.name
            color: row.isSelected ? Color.accent : root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: row.isFolder
            elide: Text.ElideRight
          }

          TextField {
            id: renameField
            visible: row.renaming
            anchors.left: icon.right
            anchors.leftMargin: Style.spacing.controlGap
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            verticalPadding: Style.spacing.xs
            property bool _done: false

            onVisibleChanged: if (visible) {
              _done = false
              text = row.modelData.name
              forceActiveFocus()
              selectAll()
            }
            onAccepted: { _done = true; root.commitRename(text) }
            Keys.onEscapePressed: { _done = true; root.cancelRename() }
            // Clicking elsewhere commits what was typed.
            onActiveFocusChanged: if (!activeFocus && row.renaming && !_done) { _done = true; root.commitRename(text) }
          }

          Row {
            id: actions
            visible: row.showActions
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            PanelActionButton {
              visible: row.isFolder
              iconText: Model.GLYPH.plus
              tooltipText: "New prompt in this folder"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              onClicked: { root.selectedId = row.modelData.id; root.newPromptRequested(row.modelData.id) }
            }
            PanelActionButton {
              visible: !row.isFolder
              iconText: Model.GLYPH.pencil
              tooltipText: "Edit prompt"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              onClicked: root.promptEditRequested(row.modelData.id)
            }
            PanelActionButton {
              iconText: Model.GLYPH.rename
              tooltipText: "Rename (r)"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              onClicked: root.beginRename(row.modelData.id, false)
            }
            PanelActionButton {
              iconText: Model.GLYPH.trash
              tooltipText: "Delete (x)"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              hoverColor: Color.urgent
              onClicked: root.deleteRequested(row.modelData.id)
            }
          }
        }
      }
    }
  }
}
