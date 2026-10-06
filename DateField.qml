import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Model.js" as Model

// A date as an ISO string (yyyy-mm-dd): a button that opens a month calendar.
Item {
  id: root

  property string value: ""
  property color foreground: Color.foreground
  signal changed(string value)

  implicitWidth: Style.spacing.dropdownWidth
  implicitHeight: Style.spacing.controlHeight

  readonly property var picked: Model.parseIso(value)
  property int viewYear: 2026
  property int viewMonth: 0   // 0-11

  readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"]
  readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

  function _showMonthOf(d) { viewYear = d.getFullYear(); viewMonth = d.getMonth() }
  function _shift(delta) {
    var d = new Date(viewYear, viewMonth + delta, 1)
    _showMonthOf(d)
  }
  function _select(d) {
    root.changed(Model.isoDate(d))
    popup.close()
  }

  // 42 cells starting on the Monday on or before the 1st.
  readonly property var cells: {
    var first = new Date(viewYear, viewMonth, 1)
    var offset = (first.getDay() + 6) % 7
    var out = []
    for (var i = 0; i < 42; i++) out.push(new Date(viewYear, viewMonth, 1 - offset + i))
    return out
  }

  BorderSurface {
    id: trigger
    anchors.fill: parent
    radius: Style.cornerRadius
    readonly property bool _hot: triggerHover.hovered
    readonly property var _spec: Border.controlSpec(trigger.activeFocus ? "focus" : (_hot ? "hover-cursor" : "normal"), root.foreground, Color.accent)
    color: Style.controlFill(trigger.activeFocus, _hot, root.foreground, Color.accent)
    borderSpec: _spec
    activeFocusOnTab: true

    HoverHandler { id: triggerHover }

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        popup.opened ? popup.close() : popup.open()
        event.accepted = true
      }
    }

    Text {
      anchors.left: parent.left
      anchors.right: glyph.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
      textFormat: Text.PlainText
      text: root.value !== "" ? root.value : "Pick a date…"
      color: root.value !== "" ? root.foreground : Qt.darker(root.foreground, 1.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      id: glyph
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
      textFormat: Text.PlainText
      text: Model.GLYPH.calendar
      color: Qt.darker(root.foreground, 1.2)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: { trigger.forceActiveFocus(); popup.opened ? popup.close() : popup.open() }
    }

    Popup {
      id: popup
      x: 0
      y: trigger.height + Style.spacing.xxs
      width: Math.max(trigger.width, Style.space(250))
      padding: Style.spacing.rowGap
      focus: true
      readonly property var spec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.normalBorderWidth)

      background: BorderSurface {
        color: Color.popups.background
        borderSpec: popup.spec
        radius: Style.cornerRadius
      }

      onAboutToShow: root._showMonthOf(root.picked || new Date())

      contentItem: Column {
        spacing: Style.spacing.xs

        Item {
          width: parent.width
          height: Style.spacing.controlHeight
          PanelActionButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅁"
            foreground: root.foreground
            onClicked: root._shift(-1)
          }
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.monthNames[root.viewMonth] + " " + root.viewYear
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }
          PanelActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰅂"
            foreground: root.foreground
            onClicked: root._shift(1)
          }
        }

        Grid {
          id: grid
          columns: 7
          readonly property real cellW: Math.floor(width / 7)
          width: parent.width

          Repeater {
            model: root.weekdays
            delegate: Text {
              required property string modelData
              width: grid.cellW
              height: Style.space(22)
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              text: modelData
              color: Qt.darker(root.foreground, 1.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Repeater {
            model: root.cells
            delegate: Rectangle {
              id: cell
              required property var modelData
              readonly property bool inMonth: modelData.getMonth() === root.viewMonth
              readonly property bool isPicked: root.picked !== null && Model.isoDate(modelData) === root.value
              readonly property bool isToday: Model.isoDate(modelData) === Model.isoDate(new Date())
              width: grid.cellW
              height: Style.space(28)
              radius: Style.cornerRadius
              color: isPicked ? Style.selectedFillFor(root.foreground, Color.accent)
                   : cellMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              border.width: isToday && !isPicked ? 1 : 0
              border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.7)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: cell.modelData.getDate()
                color: cell.isPicked ? Color.accent : root.foreground
                opacity: cell.inMonth ? 1 : 0.35
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: cell.isPicked
              }
              MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._select(cell.modelData)
              }
            }
          }
        }

        Item {
          width: parent.width
          height: todayBtn.implicitHeight
          Button {
            id: todayBtn
            anchors.right: parent.right
            text: "Today"
            bordered: true
            fontSize: Style.font.bodySmall
            verticalPadding: Style.spacing.xs
            onClicked: root._select(new Date())
          }
        }
      }
    }
  }
}
