import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Flashes each screen's connector name and size on that screen for a moment,
// so you can tell which physical display is which.
Item {
  id: root

  property var displays: []
  property bool showing: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  function flash() { root.showing = true; hide.restart() }
  Timer { id: hide; interval: 2600; onTriggered: root.showing = false }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      readonly property var info: root.displays.filter(function(d) { return d.name === modelData.name })[0] || null

      screen: modelData
      visible: root.showing
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-display-identify"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      implicitWidth: card.width
      implicitHeight: card.height

      Rectangle {
        id: card
        width: Style.space(220)
        height: Style.space(110)
        color: Qt.rgba(0.05, 0.05, 0.08, 0.92)
        border.width: Math.max(2, Style.space(2))
        border.color: root.accent

        Column {
          anchors.centerIn: parent
          spacing: Style.space(4)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: win.modelData.name
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: win.info ? win.info.label : ""
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: win.info ? win.info.width + " x " + win.info.height + "  @ " + Math.round(win.info.refresh) + " Hz" : ""
            color: Qt.rgba(1, 1, 1, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
