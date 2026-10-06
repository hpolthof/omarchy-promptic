import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Modal chooser for a directory or a file, drawn in the shell's own style so
// it needs no desktop portal. mode: "dir" picks the folder you are looking
// at; "file" picks a file from the list.
Item {
  id: root

  property bool opened: false
  property string mode: "file"
  property string startPath: ""
  property color foreground: Color.foreground

  signal picked(string path)
  signal canceled()

  visible: opened

  readonly property string home: Quickshell.env("HOME") || "/"
  property string dir: home
  property bool showHidden: false

  function dirname(p) {
    var s = String(p).replace(/\/+$/, "")
    var i = s.lastIndexOf("/")
    return i <= 0 ? "/" : s.slice(0, i)
  }

  function show(mode, current) {
    root.mode = mode
    var p = String(current || "").trim()
    if (p.charAt(0) === "~") p = home + p.slice(1)
    if (p.charAt(0) !== "/") p = home
    // For a file, start next to it; for a directory, start inside it.
    root.dir = mode === "file" && !/\/$/.test(p) ? dirname(p) : (p.length > 1 ? p.replace(/\/+$/, "") : p)
    root.showHidden = false
    root.opened = true
    Qt.callLater(function() { list.forceActiveFocus() })
  }

  function go(path) {
    var p = String(path).trim()
    if (p === "") return
    if (p.charAt(0) === "~") p = home + p.slice(1)
    if (p.charAt(0) !== "/") return
    root.dir = p.length > 1 ? p.replace(/\/+$/, "") : p
    pathField.text = root.dir
    list.currentIndex = -1
  }

  function activate(i) {
    if (i < 0 || i >= folderModel.count) return
    var path = folderModel.get(i, "filePath")
    if (folderModel.get(i, "fileIsDir")) root.go(path)
    else if (root.mode === "file") { root.opened = false; root.picked(path) }
  }

  onDirChanged: pathField.text = root.dir

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) { root.canceled(); event.accepted = true }
  }

  FolderListModel {
    id: folderModel
    folder: "file://" + encodeURI(root.dir).replace(/#/g, "%23").replace(/\?/g, "%3F")
    showDirs: true
    showFiles: root.mode === "file"
    showDotAndDotDot: false
    showHidden: root.showHidden
    showDirsFirst: true
    sortField: FolderListModel.Name
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.78)
    MouseArea { anchors.fill: parent; onClicked: root.canceled() }

    BorderSurface {
      id: card
      width: Math.min(parent.width - Style.space(32), Style.space(560))
      height: Math.min(parent.height - Style.space(32), Style.space(460))
      anchors.centerIn: parent
      color: Color.background
      borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
      padding: Style.space(14)
      radius: Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        Text {
          id: title
          anchors.top: parent.top
          anchors.left: parent.left
          textFormat: Text.PlainText
          text: root.mode === "dir" ? "Choose a folder" : "Choose a file"
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Row {
          id: nav
          anchors.top: title.bottom
          anchors.topMargin: Style.spacing.rowGap
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.spacing.xs

          PanelActionButton {
            id: upBtn
            iconText: "󰁝"
            tooltipText: "Parent folder"
            foreground: root.foreground
            bordered: true
            onClicked: root.go(root.dirname(root.dir))
          }
          PanelActionButton {
            id: homeBtn
            iconText: "󰋜"
            tooltipText: "Home"
            foreground: root.foreground
            bordered: true
            onClicked: root.go(root.home)
          }
          PanelActionButton {
            id: hiddenBtn
            iconText: root.showHidden ? "󰈈" : "󰈉"
            tooltipText: root.showHidden ? "Hide hidden files" : "Show hidden files"
            foreground: root.foreground
            bordered: true
            onClicked: root.showHidden = !root.showHidden
          }
          TextField {
            id: pathField
            width: nav.width - (upBtn.width + homeBtn.width + hiddenBtn.width) - nav.spacing * 3
            text: root.dir
            onAccepted: { root.go(text); list.forceActiveFocus() }
            Keys.onEscapePressed: list.forceActiveFocus()
          }
        }

        ListView {
          id: list
          anchors.top: nav.bottom
          anchors.topMargin: Style.spacing.rowGap
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footer.top
          anchors.bottomMargin: Style.spacing.rowGap
          clip: true
          model: folderModel
          currentIndex: -1
          boundsBehavior: Flickable.StopAtBounds
          keyNavigationEnabled: false
          spacing: 1

          Keys.onPressed: function(event) {
            var k = event.key
            var t = event.text
            if (k === Qt.Key_Escape) root.canceled()
            else if (k === Qt.Key_Down || t === "j") currentIndex = Math.min(count - 1, currentIndex + 1)
            else if (k === Qt.Key_Up || t === "k") currentIndex = Math.max(0, currentIndex - 1)
            else if (k === Qt.Key_Left || k === Qt.Key_Backspace || t === "h") root.go(root.dirname(root.dir))
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Right || t === "l") {
              if (currentIndex < 0 && root.mode === "dir" && (k === Qt.Key_Return || k === Qt.Key_Enter)) {
                root.opened = false; root.picked(root.dir)
              } else root.activate(currentIndex)
            } else return
            event.accepted = true
            positionViewAtIndex(currentIndex, ListView.Contain)
          }

          delegate: Rectangle {
            id: item
            required property int index
            required property string fileName
            required property bool fileIsDir
            width: list.width
            height: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: list.currentIndex === index || itemMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

            Text {
              id: ico
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: item.fileIsDir ? Model.GLYPH.folder : Model.GLYPH.prompt
              color: item.fileIsDir ? Color.accent : Qt.darker(root.foreground, 1.3)
              font.family: Style.font.family
              font.pixelSize: Style.font.icon
            }
            Text {
              anchors.left: ico.right
              anchors.leftMargin: Style.spacing.controlGap
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.controlPaddingX
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: item.fileName
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              elide: Text.ElideMiddle
            }
            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { list.currentIndex = item.index; root.activate(item.index) }
            }
          }

          Text {
            visible: list.count === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.mode === "dir" ? "No subfolders here." : "Nothing here."
            color: Qt.darker(root.foreground, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        Item {
          id: footer
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: cancelBtn.implicitHeight

          Row {
            anchors.right: parent.right
            spacing: Style.spacing.controlGap
            Button {
              id: cancelBtn
              text: "Cancel"
              bordered: true
              onClicked: root.canceled()
            }
            Button {
              visible: root.mode === "dir"
              text: "Select this folder"
              bordered: true
              selected: true
              onClicked: { root.opened = false; root.picked(root.dir) }
            }
          }
        }
      }
    }
  }
}
