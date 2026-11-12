import QtQuick
import qs.Commons
import qs.Commons as Commons

// The four layouts as cards, plus a row for which side the second screen goes
// on when extending. Used by the bar popup (compact) and by the Super+P
// overlay (large, with `big: true`).
Column {
  id: root

  property string current: "single"        // from Model.layoutMode()
  property string side: "right"
  property bool canSwitch: false            // a second screen is connected
  property bool showSides: true
  property bool big: false
  property string hoverMode: ""
  property bool sideHighlight: current === "extend"
  property int cursorIndex: -1              // keyboard highlight (overlay)
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal layoutChosen(string mode)
  signal sideChosen(string side)

  readonly property var cards: [
    { mode: "extend",   title: "Extend",       short: "Extend", caption: "Use the other screen as extra desktop" },
    { mode: "mirror",   title: "Mirror",       short: "Mirror", caption: "Show the same picture on both" },
    { mode: "internal", title: "Laptop only",  short: "Laptop", caption: "Laptop screen only, the other one turns off" },
    { mode: "external", title: "Screen only",  short: "Screen", caption: "Other screen only, the laptop screen turns off" }
  ]
  readonly property var sides: [
    { side: "left",  glyph: "󰁍", label: "Left" },
    { side: "right", glyph: "󰁔", label: "Right" },
    { side: "up",    glyph: "󰁝", label: "Above" },
    { side: "down",  glyph: "󰁅", label: "Below" }
  ]

  spacing: Style.space(10)

  Grid {
    id: grid
    width: parent.width
    columns: 4
    spacing: Style.space(root.big ? 12 : 8)
    readonly property real cardW: (width - spacing * (columns - 1)) / columns

    Repeater {
      model: root.cards

      Rectangle {
        id: card
        required property var modelData
        required property int index

        readonly property bool isCurrent: root.current === modelData.mode
        // Laptop only is always reachable; the rest need a second screen.
        readonly property bool usable: root.canSwitch || modelData.mode === "internal"
        readonly property bool cursor: root.cursorIndex === index

        width: grid.cardW
        height: root.big ? Style.space(140) : Style.space(72)
        color: isCurrent ? Style.selectedFillFor(root.foreground, root.accent)
             : (mouse.containsMouse || cursor) && usable ? Style.hoverFillFor(root.foreground, root.accent)
             : root.big ? Qt.rgba(0.04, 0.05, 0.08, 0.5) : Util.alpha(root.foreground, 0.035)
        border.width: isCurrent || cursor ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
        border.color: isCurrent || cursor ? root.accent : Util.alpha(root.foreground, mouse.containsMouse && usable ? 0.4 : 0.22)
        radius: Style.cornerRadius > 0 ? Style.space(4) : 0
        opacity: usable ? 1 : 0.42

        Behavior on color { ColorAnimation { duration: 110 } }

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(root.big ? 14 : 9)
          spacing: Style.space(root.big ? 10 : 5)

          LayoutIcon {
            kind: card.modelData.mode
            color: card.isCurrent || card.cursor ? root.accent : root.foreground
            unit: Style.space(root.big ? 1.7 : 0.85)
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.big ? card.modelData.title : card.modelData.short
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.big ? Style.font.title : Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            visible: root.big
            width: parent.width
            textFormat: Text.PlainText
            text: card.modelData.caption
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: root.big ? Style.font.bodySmall : Style.font.caption
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }

        // Tick in the corner of the active layout.
        Text {
          visible: card.isCurrent
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: Style.space(7)
          text: "󰄬"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: card.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: if (card.usable) root.layoutChosen(card.modelData.mode)
          onContainsMouseChanged: root.hoverMode = containsMouse ? card.modelData.mode : (root.hoverMode === card.modelData.mode ? "" : root.hoverMode)
        }
      }
    }
  }

  // One line of help under the compact cards: hovered layout, else current.
  Text {
    visible: !root.big
    width: parent.width
    textFormat: Text.PlainText
    text: {
      var m = root.hoverMode !== "" ? root.hoverMode : (root.current === "single" ? "internal" : root.current)
      for (var i = 0; i < root.cards.length; i++) if (root.cards[i].mode === m) return root.cards[i].caption
      return ""
    }
    color: Qt.darker(root.foreground, 1.4)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }

  // Where the second screen sits when extended.
  Item {
    visible: root.showSides && root.canSwitch
    width: parent.width
    height: sideRow.implicitHeight

    Text {
      id: sideLabel
      anchors.left: root.big ? undefined : parent.left
      anchors.right: root.big ? sideRow.left : undefined
      anchors.rightMargin: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      text: "SECOND SCREEN ON THE"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    Row {
      id: sideRow
      anchors.right: root.big ? undefined : parent.right
      anchors.horizontalCenter: root.big ? parent.horizontalCenter : undefined
      anchors.horizontalCenterOffset: root.big ? Style.space(70) : 0
      spacing: Style.space(4)

      Repeater {
        model: root.sides

        Rectangle {
          id: chip
          required property var modelData
          readonly property bool on: root.side === modelData.side && root.sideHighlight
          width: chipText.implicitWidth + Style.space(16)
          height: Style.space(24)
          color: on ? Style.selectedFillFor(root.foreground, root.accent)
               : chipMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
          border.width: Math.max(1, Style.space(1))
          border.color: on ? root.accent : Util.alpha(root.foreground, 0.3)
          radius: Style.cornerRadius > 0 ? Style.space(3) : 0

          Text {
            id: chipText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: chip.modelData.glyph
            color: chip.on ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
          }
          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sideChosen(chip.modelData.side)
          }
        }
      }
    }
  }
}
