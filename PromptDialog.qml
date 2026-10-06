import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Popup for adding or editing a prompt: a name, the folder it lives in and a
// resizable text box for the prompt itself.
Item {
  id: root

  property var host: null
  property color foreground: Color.foreground

  property bool opened: false
  property string editId: ""        // "" = new prompt
  property string parentId: ""

  readonly property var store: host && host.store ? host.store : null
  readonly property var nodes: store ? store.nodes : []
  readonly property bool canSave: nameField.text.trim() !== ""

  signal saved(string id)
  signal closed()

  visible: opened

  function openNew(parent) {
    root.editId = ""
    root.parentId = parent || ""
    nameField.text = ""
    area.text = ""
    root.opened = true
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function openEdit(id) {
    var n = store ? Model.find(root.nodes, id) : null
    if (!n || n.type !== "prompt") return
    root.editId = id
    root.parentId = n.parentId
    nameField.text = n.name
    area.text = n.content
    root.opened = true
    Qt.callLater(function() { area.forceActiveFocus() })
  }

  function cancel() { root.opened = false; root.closed() }

  function save() {
    if (!root.canSave || !root.store) return
    var id = root.editId
    if (id === "") id = root.store.addPrompt(root.parentId, nameField.text.trim(), area.text)
    else root.store.updatePrompt(id, { name: nameField.text, content: area.text, parentId: root.parentId })
    root.opened = false
    root.saved(id)
  }

  readonly property var fieldPreview: Model.parse(area.text).fields

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) { root.cancel(); event.accepted = true }
    else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      root.save(); event.accepted = true
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.78)
    MouseArea { anchors.fill: parent; onClicked: {} }

    BorderSurface {
      id: card
      width: Math.min(parent.width - Style.space(32), Style.space(680))
      height: Math.min(parent.height - Style.space(32), Style.space(560))
      anchors.centerIn: parent
      color: Color.background
      borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
      padding: Style.space(16)
      radius: Style.cornerRadius

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Text {
          id: heading
          anchors.top: parent.top
          anchors.left: parent.left
          textFormat: Text.PlainText
          text: root.editId === "" ? "New prompt" : "Edit prompt"
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Row {
          id: top
          anchors.top: heading.bottom
          anchors.topMargin: Style.spacing.rowGap
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.spacing.panelGap

          Column {
            width: (parent.width - parent.spacing) * 0.55
            spacing: Style.spacing.labelGap
            PanelSectionHeader { text: "NAME"; foreground: root.foreground }
            TextField {
              id: nameField
              width: parent.width
              placeholderText: "Name of the prompt"
              onAccepted: area.forceActiveFocus()
              Keys.onTabPressed: area.forceActiveFocus()
              Keys.onBacktabPressed: area.forceActiveFocus()
            }
          }

          Dropdown {
            width: (parent.width - parent.spacing) * 0.45
            label: "FOLDER"
            foreground: root.foreground
            options: Model.folderOptions(root.nodes, "")
            value: root.parentId
            onChanged: function(v) { root.parentId = v }
          }
        }

        PanelSectionHeader {
          id: contentHeader
          anchors.top: top.bottom
          anchors.topMargin: Style.spacing.rowGap
          anchors.left: parent.left
          text: "PROMPT"
          foreground: root.foreground
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: contentHeader.verticalCenter
          textFormat: Text.PlainText
          text: "{{ Label }}  {{ Label || default }}  {{ Label | [A,B] }}  | yesno  | date  | dir  | file"
          color: Qt.darker(root.foreground, 1.7)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideLeft
          width: Math.min(implicitWidth, parent.width - contentHeader.width - Style.spacing.rowGap)
        }

        BorderSurface {
          id: frame
          anchors.top: contentHeader.bottom
          anchors.topMargin: Style.spacing.labelGap
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footer.top
          anchors.bottomMargin: Style.spacing.rowGap
          radius: Style.cornerRadius
          readonly property bool _hot: frameHover.hovered
          color: Style.controlFill(area.activeFocus, _hot, root.foreground, Color.accent)
          borderSpec: Border.controlSpec(area.activeFocus ? "focus" : (_hot ? "hover-cursor" : "normal"), root.foreground, Color.accent)
          HoverHandler { id: frameHover }

          Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Style.normalBorderWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: area.height

            ScrollBar.vertical: ScrollBar {
              id: vbar
              policy: ScrollBar.AsNeeded
              background: null
              contentItem: Rectangle {
                implicitWidth: Style.space(4)
                radius: width / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, vbar.pressed ? 0.5 : 0.28)
              }
            }

            TextArea.flickable: TextArea {
              id: area
              width: flick.width
              height: Math.max(implicitHeight, flick.height)
              wrapMode: TextEdit.Wrap
              textFormat: TextEdit.PlainText
              selectByMouse: true
              placeholderText: "Type or paste your prompt. Wrap anything you want to fill in later in {{ double braces }}."
              placeholderTextColor: Qt.darker(root.foreground, 1.6)
              color: root.foreground
              selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
              selectedTextColor: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              leftPadding: Style.spacing.controlPaddingX
              rightPadding: Style.spacing.controlPaddingX
              topPadding: Style.spacing.inputPaddingY
              bottomPadding: Style.spacing.inputPaddingY
              background: null

              onCursorRectangleChanged: {
                if (!activeFocus) return
                var r = cursorRectangle
                if (r.y < flick.contentY) flick.contentY = r.y
                else if (r.y + r.height > flick.contentY + flick.height)
                  flick.contentY = r.y + r.height - flick.height
              }
              Keys.onTabPressed: nameField.forceActiveFocus()
              Keys.onBacktabPressed: nameField.forceActiveFocus()
            }
          }
        }

        Item {
          id: footer
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: saveBtn.implicitHeight

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.fieldPreview.length === 0 ? "No placeholders"
                : root.fieldPreview.length + (root.fieldPreview.length === 1 ? " placeholder" : " placeholders")
            color: Qt.darker(root.foreground, 1.85)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Row {
            anchors.right: parent.right
            spacing: Style.spacing.controlGap
            Button {
              text: "Cancel"
              bordered: true
              onClicked: root.cancel()
            }
            Button {
              id: saveBtn
              text: root.editId === "" ? "Add prompt" : "Save"
              bordered: true
              selected: root.canSave
              enabled: root.canSave
              opacity: enabled ? 1 : 0.5
              onClicked: root.save()
            }
          }
        }
      }
    }
  }
}
