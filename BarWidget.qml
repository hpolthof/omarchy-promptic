import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Host: owns the Store, the clipboard process and the panel. Panel.qml binds
// directly to the properties below.
BarWidget {
  id: root
  moduleName: "io.github.hpolthof.promptic"

  property alias store: prStore

  // "" | "copied" | "failed"; resets by itself.
  property string copyState: ""
  property string _copyText: ""

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  Store { id: prStore }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("anchorItem" in target) target.anchorItem = button
    if ("host" in target) target.host = root
    if ("bar" in target) target.bar = root.bar
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  onBarChanged: root.injectPanel()

  // ------------------------------------------------------------- clipboard

  // The prompt goes to wl-copy on standard input, never on the command line.
  function copy(text) {
    if (copyProc.running) return
    root._copyText = String(text)
    copyProc.stdinEnabled = true
    copyProc.running = true
  }

  Process {
    id: copyProc
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      write(root._copyText)
      stdinEnabled = false
    }
    onExited: function(code) {
      root._copyText = ""
      root.copyState = code === 0 ? "copied" : "failed"
      copyReset.restart()
    }
  }

  Timer {
    id: copyReset
    interval: 2200
    onTriggered: root.copyState = ""
  }

  // ------------------------------------------------------------- lifecycle

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "io.github.hpolthof.promptic"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    hasVisualContent: true
    fixedWidth: vertical ? -1 : icon.size + scaledHorizontalMargin * 2
    fixedHeight: vertical ? icon.size + scaledVerticalPadding * 2 : -1

    PrompticIcon {
      id: icon
      anchors.centerIn: parent
      size: Math.round(Style.font.icon * 1.1)
      color: button.foreground
      strokeWidth: 2.1
    }
    tooltipText: "Promptic"
    onPressed: function(mouseButton) { root.toggle() }
  }
}
