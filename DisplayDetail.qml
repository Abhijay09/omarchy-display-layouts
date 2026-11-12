import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// Everything about the screen picked on the arrangement map: resolution and
// refresh rate, rotation, and moving windows or the workspace onto it.
Column {
  id: root

  property var display: null            // one entry from Model.parseMonitors()
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal modeChosen(string output, string mode)
  signal rotateChosen(string output, int transform)
  signal sendWindow(string output)
  signal sendWorkspace(string output)
  signal identify()

  readonly property bool live: display !== null && display.enabled
  readonly property var rotations: [
    { t: 0, label: "0°" }, { t: 1, label: "90°" }, { t: 2, label: "180°" }, { t: 3, label: "270°" }
  ]

  spacing: Style.space(10)
  visible: display !== null

  Row {
    spacing: Style.space(8)
    width: parent.width
    Text {
      text: root.display && root.display.internal ? "󰌢" : "󰍹"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
    }
    Text {
      width: parent.width - Style.space(30)
      textFormat: Text.PlainText
      text: root.display ? root.display.name + (root.display.label !== root.display.name ? "  ·  " + root.display.label : "") : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Item {
    width: parent.width
    height: Style.spacing.controlHeight
    visible: root.live && root.display.modes.length > 1

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "RESOLUTION"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }
    Dropdown {
      anchors.right: parent.right
      width: Math.min(parent.width * 0.62, Style.space(220))
      showLabel: false
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      options: root.display ? root.display.modes.map(function(m) { return { value: m.value, label: m.label } }) : []
      value: root.display ? Model.currentModeValue(root.display) : ""
      onChanged: function(v) { root.modeChosen(root.display.name, v) }
    }
  }

  Item {
    width: parent.width
    height: Style.space(26)
    visible: root.live

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "ROTATION"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }
    Row {
      anchors.right: parent.right
      spacing: Style.space(4)
      Repeater {
        model: root.rotations
        Rectangle {
          id: rot
          required property var modelData
          readonly property bool on: root.display && root.display.transform === modelData.t
          width: Style.space(46)
          height: Style.space(24)
          color: on ? Style.selectedFillFor(root.foreground, root.accent)
               : rotMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
          border.width: Math.max(1, Style.space(1))
          border.color: on ? root.accent : Util.alpha(root.foreground, 0.3)
          radius: Style.cornerRadius > 0 ? Style.space(3) : 0
          Text {
            anchors.centerIn: parent
            text: rot.modelData.label
            color: rot.on ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          MouseArea {
            id: rotMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!rot.on) root.rotateChosen(root.display.name, rot.modelData.t)
          }
        }
      }
    }
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)
    visible: root.live

    Repeater {
      model: [
        { id: "window",    label: "󰖲  Send window here" },
        { id: "workspace", label: "󰕮  Move workspace here" },
        { id: "identify",  label: "󰋼  Identify" }
      ]
      Button {
        required property var modelData
        text: modelData.label
        fontSize: Style.font.caption
        foreground: root.foreground
        fontFamily: root.fontFamily
        horizontalPadding: Style.spacing.sm
        verticalPadding: Style.spacing.controlPaddingY
        bordered: true
        onClicked: {
          if (modelData.id === "window") root.sendWindow(root.display.name)
          else if (modelData.id === "workspace") root.sendWorkspace(root.display.name)
          else root.identify()
        }
      }
    }
  }

  Text {
    visible: root.display !== null && !root.display.enabled
    width: parent.width
    wrapMode: Text.Wrap
    text: "This screen is switched off. Pick Extend or Screen only above to bring it back."
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
