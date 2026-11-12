import QtQuick
import QtQuick.Effects
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

  // Closes itself when nothing is chosen. Any key, hover or click starts the
  // countdown over, so it never closes while it is being used.
  readonly property int idleMs: 10000
  property real remaining: 1
  function touch() {
    if (!ov.opened) return
    idle.restart()
    countdown.restart()
  }
  Timer { id: idle; interval: ov.idleMs; onTriggered: ov.close() }
  NumberAnimation { id: countdown; target: ov; property: "remaining"; from: 1; to: 0; duration: ov.idleMs }

  function usable(i) { return ov.canSwitch || ov.modes[i] === "internal" }

  function open() {
    var at = ov.modes.indexOf(ov.current)
    ov.index = at >= 0 ? at : (ov.canSwitch ? 0 : 2)
    ov.pendingSide = ov.side
    ov.cycled = false
    ov.opened = true
    ov.touch()
    Qt.callLater(function() { if (ov.opened) keys.forceActiveFocus() })
  }
  function close() { ov.opened = false; ov.cycled = false; idle.stop(); countdown.stop() }
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
    ov.touch()
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
    ov.touch()
    var order = ["right", "down", "left", "up"]
    ov.pendingSide = order[(order.indexOf(ov.pendingSide) + 1) % order.length]
  }

  PanelWindow {
    id: win
    visible: ov.opened
    screen: ov.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-display-project"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Frosted backdrop: one frame of the screen is captured as the picker
    // opens (while the window is still see-through, so it doesn't capture
    // itself), blurred, and tinted. If the capture never arrives, a plain dark
    // scrim takes over so the text stays readable.
    Item {
      id: backdrop
      anchors.fill: parent
      property bool ready: false
      property bool gaveUp: false
      opacity: ov.opened ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }

      Connections {
        target: win
        function onVisibleChanged() { if (!win.visible) { backdrop.ready = false; backdrop.gaveUp = false } }
      }
      Timer { running: ov.opened && !backdrop.ready; interval: 700; onTriggered: backdrop.gaveUp = true }

      Loader {
        id: shot
        anchors.fill: parent
        active: ov.opened
        sourceComponent: ScreencopyView {
          captureSource: win.screen
          live: false
          paintCursor: false
          onHasContentChanged: if (hasContent) backdrop.ready = true
        }
      }

      MultiEffect {
        anchors.fill: parent
        source: shot.item
        visible: shot.item !== null
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        blurMultiplier: 1.4
        brightness: -0.1
        saturation: -0.15
        opacity: backdrop.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.04, 0.07, 0.5)
        opacity: backdrop.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }
      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.04, 0.86)
        opacity: backdrop.gaveUp && !backdrop.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: ov.close()
        onPositionChanged: ov.touch()
      }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(e) {
        ov.touch()
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
          onHoverModeChanged: ov.touch()
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

        // Time left before it closes by itself.
        Item {
          width: parent.width
          height: Math.max(2, Style.space(2))
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, Style.space(260)) * ov.remaining
            height: parent.height
            color: Qt.rgba(1, 1, 1, 0.35)
          }
        }
      }
    }
  }
}
