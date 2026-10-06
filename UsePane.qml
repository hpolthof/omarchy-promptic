import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Right column: the form for the selected prompt, a live preview of the
// finished text and the copy button.
Item {
  id: root

  property var host: null
  property var prompt: null
  property var nodes: []
  property color foreground: Color.foreground

  signal editRequested(string id)
  signal browseRequested(string key, string mode, string current)
  signal copyRequested()
  signal escapePressed()

  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.85)

  readonly property string promptId: prompt ? prompt.id : ""
  readonly property string content: prompt ? prompt.content : ""
  readonly property var parsed: Model.parse(content)
  readonly property var fields: parsed.fields
  property var values: ({})
  property var cache: ({})   // typed values per prompt, kept while the panel is loaded

  readonly property string output: Model.render(parsed, values)
  readonly property int empties: Model.emptyCount(fields, values)

  function setValue(key, v) {
    var next = Object.assign({}, root.values)
    next[key] = String(v)
    root.values = next
    if (root.promptId !== "") root.cache[root.promptId] = { content: root.content, values: next }
  }

  function rebuild() {
    var base = Model.defaults(root.fields, new Date())
    var c = root.cache[root.promptId]
    if (c && c.content === root.content) {
      for (var k in base) if (c.values[k] !== undefined) base[k] = c.values[k]
    }
    root.values = base
  }

  // Rebuilds when another prompt is chosen or its text changes (not on rename).
  readonly property string signature: promptId + "\u0000" + content
  onSignatureChanged: { root.rebuild(); formFlick.contentY = 0 }
  Component.onCompleted: root.rebuild()

  function copy() {
    if (!root.prompt || !root.host) return
    root.host.copy(root.output)
  }

  readonly property string copyState: host ? host.copyState : ""

  // ---------------------------------------------------------------- empty

  Text {
    visible: !root.prompt
    anchors.centerIn: parent
    width: parent.width - Style.space(48)
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    text: "Pick a prompt on the left to fill it in and copy it."
    color: root.dim
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  FocusScope {
    id: focusScope
    anchors.fill: parent
    visible: root.prompt !== null

    // ------------------------------------------------------------ header
    Item {
      id: head
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: titleCol.implicitHeight

      Column {
        id: titleCol
        anchors.left: parent.left
        anchors.right: editBtn.left
        anchors.rightMargin: Style.spacing.controlGap
        spacing: Style.spacing.xxs
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.prompt ? root.prompt.name : ""
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.prompt ? Model.pathOf(root.nodes, root.prompt.parentId).concat([]).join(" / ") || "Library" : ""
          color: root.faint
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }

      Button {
        id: editBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Edit"
        iconText: Model.GLYPH.pencil
        bordered: true
        onClicked: root.editRequested(root.promptId)
      }
    }

    PanelSeparator {
      id: rule
      anchors.top: head.bottom
      anchors.topMargin: Style.spacing.rowGap
      foreground: root.foreground
    }

    // -------------------------------------------------------------- footer
    Item {
      id: foot
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: copyBtn.implicitHeight

      Text {
        anchors.left: parent.left
        anchors.right: copyBtn.left
        anchors.rightMargin: Style.spacing.controlGap
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.fields.length === 0 ? "No placeholders in this prompt"
            : root.empties === 0 ? "All fields filled in"
            : root.empties + (root.empties === 1 ? " field is still empty" : " fields are still empty")
        color: root.empties > 0 ? root.dim : root.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Button {
        id: copyBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        bordered: true
        selected: root.copyState === "copied"
        iconText: root.copyState === "copied" ? Model.GLYPH.check : Model.GLYPH.copy
        text: root.copyState === "copied" ? "Copied"
            : root.copyState === "failed" ? "Copy failed (wl-copy)"
            : "Copy prompt"
        onClicked: root.copyRequested()
      }
    }

    // ------------------------------------------------------------ the form
    Flickable {
      id: formFlick
      anchors.top: rule.bottom
      anchors.topMargin: Style.spacing.panelGap
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: foot.top
      anchors.bottomMargin: Style.spacing.rowGap
      contentWidth: width
      contentHeight: form.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ScrollBar.vertical: ScrollBar {
        id: fbar
        policy: ScrollBar.AsNeeded
        background: null
        contentItem: Rectangle {
          implicitWidth: Style.space(4)
          radius: width / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, fbar.pressed ? 0.5 : 0.28)
        }
      }

      Column {
        id: form
        width: formFlick.width - Style.space(10)
        spacing: Style.spacing.rowGap

        PanelSectionHeader {
          visible: root.fields.length > 0
          text: "FILL IN"
          foreground: root.foreground
        }

        Repeater {
          model: root.fields

          delegate: Column {
            id: fld
            required property var modelData
            readonly property string key: modelData.key
            readonly property string val: root.values[modelData.key] === undefined ? "" : String(root.values[modelData.key])
            width: form.width
            spacing: Style.spacing.labelGap

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: fld.modelData.label
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Loader {
              width: parent.width
              sourceComponent: {
                var t = fld.modelData.type
                return t === "choice" ? choiceComp : t === "yesno" ? yesnoComp : t === "date" ? dateComp
                     : (t === "dir" || t === "file") ? pathComp : textComp
              }
            }

            // Free text: a small multi-line box that grows with its content.
            Component {
              id: textComp
              BorderSurface {
                id: tFrame
                width: parent ? parent.width : 0
                readonly property real minH: Style.spacing.controlHeight
                readonly property real maxH: Style.space(190)
                height: Math.min(maxH, Math.max(minH, tArea.contentHeight + tArea.topPadding + tArea.bottomPadding + Style.normalBorderWidth * 2))
                radius: Style.cornerRadius
                readonly property bool _hot: tHover.hovered
                color: Style.controlFill(tArea.activeFocus, _hot, root.foreground, Color.accent)
                borderSpec: Border.controlSpec(tArea.activeFocus ? "focus" : (_hot ? "hover-cursor" : "normal"), root.foreground, Color.accent)
                HoverHandler { id: tHover }

                Flickable {
                  id: tFlick
                  anchors.fill: parent
                  anchors.margins: Style.normalBorderWidth
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  contentWidth: width
                  contentHeight: tArea.height
                  TextArea.flickable: TextArea {
                    id: tArea
                    width: tFlick.width
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    selectByMouse: true
                    background: null
                    color: root.foreground
                    selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
                    selectedTextColor: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    leftPadding: Style.spacing.controlPaddingX
                    rightPadding: Style.spacing.controlPaddingX
                    topPadding: Style.spacing.inputPaddingY
                    bottomPadding: Style.spacing.inputPaddingY
                    text: fld.val
                    onTextChanged: if (text !== fld.val) root.setValue(fld.key, text)
                    onCursorRectangleChanged: {
                      if (!activeFocus) return
                      var r = cursorRectangle
                      if (r.y < tFlick.contentY) tFlick.contentY = r.y
                      else if (r.y + r.height > tFlick.contentY + tFlick.height) tFlick.contentY = r.y + r.height - tFlick.height
                    }
                    Keys.onTabPressed: nextItemInFocusChain(true).forceActiveFocus()
                    Keys.onBacktabPressed: nextItemInFocusChain(false).forceActiveFocus()
                    Keys.onEscapePressed: root.escapePressed()
                    Keys.onPressed: function(event) {
                      if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        root.copyRequested(); event.accepted = true
                      }
                    }
                  }
                }
              }
            }

            Component {
              id: choiceComp
              Dropdown {
                width: parent ? parent.width : 0
                showLabel: false
                foreground: root.foreground
                options: fld.modelData.options
                value: fld.val
                onChanged: function(v) { root.setValue(fld.key, v) }
              }
            }

            Component {
              id: yesnoComp
              Row {
                spacing: Style.spacing.controlGap
                Repeater {
                  model: ["Yes", "No"]
                  delegate: Button {
                    required property string modelData
                    focusable: true
                    bordered: true
                    selected: fld.val === modelData
                    iconText: selected ? "●" : "○"
                    iconSize: Style.font.body
                    text: modelData
                    onClicked: root.setValue(fld.key, modelData)
                  }
                }
              }
            }

            Component {
              id: dateComp
              Row {
                spacing: Style.spacing.controlGap
                DateField {
                  foreground: root.foreground
                  value: fld.val
                  onChanged: function(v) { root.setValue(fld.key, v) }
                }
                Button {
                  visible: fld.val !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: Model.GLYPH.close
                  tooltipText: "Clear"
                  onClicked: root.setValue(fld.key, "")
                }
              }
            }

            // Directory / file: an editable path plus a Browse button.
            Component {
              id: pathComp
              Row {
                spacing: Style.spacing.controlGap
                TextField {
                  id: pathField
                  width: parent.width - browse.width - parent.spacing
                  placeholderText: fld.modelData.type === "dir" ? "/path/to/folder" : "/path/to/file"
                  text: fld.val
                  onTextChanged: if (text !== fld.val) root.setValue(fld.key, text)
                  Keys.onEscapePressed: root.escapePressed()
                }
                Button {
                  id: browse
                  anchors.verticalCenter: parent.verticalCenter
                  bordered: true
                  focusable: true
                  iconText: fld.modelData.type === "dir" ? Model.GLYPH.folder : Model.GLYPH.prompt
                  text: "Browse…"
                  onClicked: root.browseRequested(fld.key, fld.modelData.type, fld.val)
                }
              }
            }
          }
        }

        PanelSectionHeader {
          text: "PREVIEW"
          foreground: root.foreground
          topPadding: Style.spacing.xs
        }

        BorderSurface {
          width: form.width
          height: previewText.implicitHeight + Style.spacing.inputPaddingY * 2 + Style.normalBorderWidth * 2
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

          Text {
            id: previewText
            anchors.fill: parent
            anchors.margins: Style.normalBorderWidth
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.rightMargin: Style.spacing.controlPaddingX
            anchors.topMargin: Style.spacing.inputPaddingY
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: root.output
            color: root.dim
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        Item { width: 1; height: Style.spacing.xs }
      }
    }
  }
}
