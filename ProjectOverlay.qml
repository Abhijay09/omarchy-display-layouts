import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Win+P style picker. Super+P opens it with the current layout selected.
// While Super is held, each extra P steps to the next layout and letting go of
// Super applies it. It also works without holding anything: arrows, Tab or P to
// move, Enter to apply, S to change the side, 1-4 to jump, Esc to cancel, or
// just click a card.
Item {
  id: ov

  property bool opened: false
  property string current: "single"
  property string side: "right"
  property bool canSwitch: false
  property var targetScreen: null
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal chosen(string mode, string side)

  readonly property var modes: ["extend", "mirror", "internal", "external"]
  property int index: 0
  property string pendingSide: "right"
  // Only a P pressed while the overlay is open arms "release Super to apply",
  // so a quick tap of Super+P never closes it before it can be used.
  property bool cycled: false

  function usable(i) { return ov.canSwitch || ov.modes[i] === "internal" }

  function open() {
    var at = ov.modes.indexOf(ov.current)
    ov.index = at >= 0 ? at : (ov.canSwitch ? 0 : 2)
    ov.pendingSide = ov.side
    ov.cycled = false
    ov.opened = true
    Qt.callLater(function() { if (ov.opened) keys.forceActiveFocus() })
  }
  function close() { ov.opened = false; ov.cycled = false }
  function toggle() { ov.opened ? ov.close() : ov.open() }

  // What the Super+P keybinding calls. First press opens the picker; while it
  // is open, every further press steps to the next layout (Hyprland keeps the
  // key for itself while Super is held, so the cycling has to come from here).
  function press() {
    if (!ov.opened) { ov.open(); return }
    ov.step(1)
    ov.cycled = true
  }
  // Apply the highlighted layout, e.g. from a Super-release binding.
  function commit() { if (ov.opened) ov.apply() }

  function step(dir) {
    for (var n = 1; n <= ov.modes.length; n++) {
      var i = (ov.index + dir * n + ov.modes.length * 4) % ov.modes.length
      if (ov.usable(i)) { ov.index = i; return }
    }
  }
  function apply() {
    var mode = ov.modes[ov.index]
    ov.close()
    if (!ov.usable(ov.index)) return
    if (mode !== ov.current || mode === "extend") ov.chosen(mode, ov.pendingSide)
  }
  function nextSide() {
    var order = ["right", "down", "left", "up"]
    ov.pendingSide = order[(order.indexOf(ov.pendingSide) + 1) % order.length]
  }

  PanelWindow {
    visible: ov.opened
    screen: ov.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-display-project"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0.02, 0.02, 0.04, 0.86)
      opacity: ov.opened ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 140 } }
      MouseArea { anchors.fill: parent; onClicked: ov.close() }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(e) {
        switch (e.key) {
        case Qt.Key_Escape: ov.close(); break
        case Qt.Key_P:
        case Qt.Key_Tab:
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_L:
        case Qt.Key_J:
          ov.step(e.key === Qt.Key_P && (e.modifiers & Qt.ShiftModifier) ? -1 : 1)
          if (e.key === Qt.Key_P) ov.cycled = true
          break
        case Qt.Key_Backtab:
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_H:
        case Qt.Key_K:
          ov.step(-1)
          break
        case Qt.Key_S: ov.nextSide(); break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space: ov.apply(); break
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4:
          var i = e.key - Qt.Key_1
          if (ov.usable(i)) ov.index = i
          break
        default: return
        }
        e.accepted = true
      }
      Keys.onReleased: function(e) {
        if (!ov.cycled) return
        if (e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R || e.key === Qt.Key_Meta) {
          ov.apply()
          e.accepted = true
        }
      }

      Column {
        id: content
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.88, Style.space(940))
        spacing: Style.space(18)

        Column {
          width: parent.width
          spacing: Style.space(4)
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "PROJECT"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: ov.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 3
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: ov.canSwitch ? "Choose how to use your screens" : "Connect a screen to see more options"
            color: "white"
            font.family: ov.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }
        }

        LayoutCards {
          width: parent.width
          big: true
          canSwitch: ov.canSwitch
          current: ov.current
          side: ov.pendingSide
          sideHighlight: ov.modes[ov.index] === "extend"
          cursorIndex: ov.index
          foreground: ov.foreground
          accent: ov.accent
          fontFamily: ov.fontFamily
          onLayoutChosen: function(mode) { ov.index = ov.modes.indexOf(mode); ov.apply() }
          onSideChosen: function(s) { ov.pendingSide = s; ov.index = 0 }
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: "Hold Super and press P to cycle  ·  Enter to apply  ·  S to switch side  ·  Esc to cancel"
          color: Qt.rgba(1, 1, 1, 0.6)
          font.family: ov.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
