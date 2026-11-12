import QtQuick
import qs.Commons
import qs.Commons as Commons

// Small line drawings for the four layouts, built from rectangles so they stay
// crisp at any scale and follow the theme colour.
Item {
  id: icon

  property string kind: "extend"        // extend | mirror | internal | external
  property color color: Commons.Color.foreground
  property real unit: Style.space(1)

  implicitWidth: 34 * unit
  implicitHeight: 22 * unit

  readonly property real line: Math.max(1.5, unit * 1.4)

  component Screen: Rectangle {
    property real u: icon.unit
    color: "transparent"
    border.width: icon.line
    border.color: icon.color
  }
  component Solid: Rectangle {
    color: icon.color
  }

  // extend: two screens side by side
  Item {
    visible: icon.kind === "extend"
    anchors.fill: parent
    Screen { x: 0;          y: 4 * icon.unit; width: 15 * icon.unit; height: 12 * icon.unit }
    Screen { x: 19 * icon.unit; y: 4 * icon.unit; width: 15 * icon.unit; height: 12 * icon.unit }
    Solid { x: 5 * icon.unit;  y: 18 * icon.unit; width: 5 * icon.unit; height: icon.line }
    Solid { x: 24 * icon.unit; y: 18 * icon.unit; width: 5 * icon.unit; height: icon.line }
  }

  // mirror: one screen echoed behind another
  Item {
    visible: icon.kind === "mirror"
    anchors.fill: parent
    Screen { x: 9 * icon.unit; y: 0; width: 24 * icon.unit; height: 15 * icon.unit; opacity: 0.55 }
    Rectangle {
      x: 0; y: 6 * icon.unit; width: 24 * icon.unit; height: 15 * icon.unit
      color: Util.alpha(icon.color, 0.14)
      border.width: icon.line
      border.color: icon.color
    }
  }

  // internal: laptop
  Item {
    visible: icon.kind === "internal"
    anchors.fill: parent
    Screen { x: 5 * icon.unit; y: 1 * icon.unit; width: 24 * icon.unit; height: 15 * icon.unit }
    Solid { x: 0; y: 18 * icon.unit; width: 34 * icon.unit; height: icon.line * 1.6 }
  }

  // external: desktop monitor on a stand
  Item {
    visible: icon.kind === "external"
    anchors.fill: parent
    Screen { x: 4 * icon.unit; y: 0; width: 26 * icon.unit; height: 16 * icon.unit }
    Solid { x: 15 * icon.unit; y: 16 * icon.unit; width: 4 * icon.unit; height: 3 * icon.unit }
    Solid { x: 10 * icon.unit; y: 19 * icon.unit; width: 14 * icon.unit; height: icon.line }
  }
}
