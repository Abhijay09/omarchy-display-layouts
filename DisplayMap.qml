import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// To-scale picture of how the screens sit next to each other. Click a screen
// to select it; drag an external screen to another side of the laptop screen
// and it snaps there on release. Mirrored screens are drawn stacked behind the
// screen they copy, and screens that are switched off sit dashed at the end.
Item {
  id: map

  property var displays: []
  property string selected: ""
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal picked(string name)
  signal sideDropped(string name, string side)

  readonly property real pad: Style.space(14)
  readonly property real mirrorShift: Style.space(9)

  implicitHeight: Style.space(122)

  // One entry per rectangle to paint, already in map pixels.
  readonly property var rects: {
    var list = map.displays
    var w = map.width, h = map.height
    if (!list || list.length === 0 || w <= 0 || h <= 0) return []

    var placed = list.filter(function(d) { return d.enabled && d.mirrorOf === "" })
    if (placed.length === 0) placed = list.filter(function(d) { return d.enabled })
    var mirrors = list.filter(function(d) { return d.enabled && d.mirrorOf !== "" && placed.indexOf(d) < 0 })
    var off = list.filter(function(d) { return !d.enabled })

    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    function grow(x, y, rw, rh) {
      minX = Math.min(minX, x); minY = Math.min(minY, y)
      maxX = Math.max(maxX, x + rw); maxY = Math.max(maxY, y + rh)
    }
    for (var i = 0; i < placed.length; i++) grow(placed[i].x, placed[i].y, placed[i].lw, placed[i].lh)
    if (!isFinite(minX)) { minX = 0; minY = 0; maxX = 1280; maxY = 800 }

    // Off screens queue up to the right of the group, top aligned.
    var gap = (maxX - minX) * 0.08
    var offPos = []
    var cursor = maxX + gap
    for (var o = 0; o < off.length; o++) {
      var ow = off[o].lw || 1280, oh = off[o].lh || 720
      offPos.push({ d: off[o], x: cursor, y: minY, w: ow, h: oh })
      grow(cursor, minY, ow, oh)
      cursor += ow + gap
    }

    var bw = Math.max(1, maxX - minX), bh = Math.max(1, maxY - minY)
    var shift = mirrors.length > 0 ? map.mirrorShift : 0
    var k = Math.min((w - map.pad * 2 - shift) / bw, (h - map.pad * 2 - shift) / bh)
    // Keep a lone screen from filling the whole strip.
    k = Math.min(k, (w * 0.46) / Math.max(1, Math.min(bw, 1920)))
    var ox = (w - bw * k + shift) / 2 - minX * k
    var oy = (h - bh * k - shift) / 2 - minY * k + shift

    var out = []
    function push(d, x, y, rw, rh, kind) {
      out.push({ d: d, kind: kind, px: ox + x * k, py: oy + y * k, pw: Math.max(24, rw * k), ph: Math.max(16, rh * k) })
    }
    for (var p = 0; p < placed.length; p++) push(placed[p], placed[p].x, placed[p].y, placed[p].lw, placed[p].lh, "normal")
    for (var m = 0; m < mirrors.length; m++) {
      var src = placed.filter(function(d) { return d.name === mirrors[m].mirrorOf })[0] || placed[0]
      if (!src) continue
      out.push({ d: mirrors[m], kind: "mirror", of: src.name,
                 px: ox + src.x * k + shift, py: oy + src.y * k - shift,
                 pw: Math.max(24, src.lw * k), ph: Math.max(16, src.lh * k) })
    }
    for (var q = 0; q < offPos.length; q++) push(offPos[q].d, offPos[q].x, offPos[q].y, offPos[q].w, offPos[q].h, "off")
    return out
  }

  // Rectangle the others are measured against while dragging.
  readonly property var anchorRect: {
    var r = map.rects
    for (var i = 0; i < r.length; i++) if (r[i].kind === "normal" && r[i].d.internal) return r[i]
    for (var j = 0; j < r.length; j++) if (r[j].kind === "normal") return r[j]
    return null
  }
  readonly property bool canDrag: {
    var n = 0
    for (var i = 0; i < map.rects.length; i++) if (map.rects[i].kind === "normal") n++
    return n >= 2
  }

  property string dragSide: ""
  property string dragName: ""

  // The side the anchor will receive the dragged screen on.
  Rectangle {
    id: dropZone
    visible: map.dragSide !== "" && map.anchorRect !== null
    z: 5
    color: Util.alpha(map.accent, 0.55)
    readonly property real t: Style.space(4)
    x: !map.anchorRect ? 0
       : map.dragSide === "left" ? map.anchorRect.px - t - Style.space(3)
       : map.dragSide === "right" ? map.anchorRect.px + map.anchorRect.pw + Style.space(3)
       : map.anchorRect.px
    y: !map.anchorRect ? 0
       : map.dragSide === "up" ? map.anchorRect.py - t - Style.space(3)
       : map.dragSide === "down" ? map.anchorRect.py + map.anchorRect.ph + Style.space(3)
       : map.anchorRect.py
    width: !map.anchorRect ? 0 : (map.dragSide === "left" || map.dragSide === "right") ? t : map.anchorRect.pw
    height: !map.anchorRect ? 0 : (map.dragSide === "up" || map.dragSide === "down") ? t : map.anchorRect.ph
  }

  Repeater {
    model: map.rects

    Item {
      id: slot
      required property var modelData
      readonly property var d: modelData.d
      readonly property bool isSelected: d.name === map.selected
      readonly property bool isMirror: modelData.kind === "mirror"
      readonly property bool isOff: modelData.kind === "off"
      readonly property bool draggable: map.canDrag && modelData.kind === "normal" && !d.internal

      x: modelData.px
      y: modelData.py
      width: modelData.pw
      height: modelData.ph
      z: isMirror ? 0 : (isSelected ? 3 : 1)

      Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      Rectangle {
        id: body
        width: slot.width
        height: slot.height
        x: 0
        y: 0
        radius: Style.cornerRadius > 0 ? Style.space(3) : 0
        color: slot.isOff ? "transparent"
             : Util.alpha(map.foreground, slot.isMirror ? 0.04 : (slot.isSelected ? 0.16 : 0.08))
        border.width: slot.isSelected ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
        border.color: slot.isSelected ? map.accent : Util.alpha(map.foreground, slot.isOff || slot.isMirror ? 0.28 : 0.5)
        opacity: slot.isOff ? 0.6 : 1
        scale: mouse.drag.active ? 1.03 : 1

        Behavior on x { enabled: !mouse.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !mouse.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 120 } }

        // Dashed look for screens that are off or mirrored: four short rails.
        Column {
          anchors.centerIn: parent
          width: parent.width - Style.space(10)
          spacing: Style.space(1)
          visible: !slot.isMirror

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: (slot.d.internal ? "󰌢" : "󰍹") + (slot.d.focused && !slot.isOff ? "  ●" : "")
            color: slot.isSelected ? map.accent : map.foreground
            font.family: map.fontFamily
            font.pixelSize: Style.font.title
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: slot.d.name
            color: map.foreground
            font.family: map.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            visible: body.height > Style.space(54)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: slot.d.label
            color: Qt.darker(map.foreground, 1.45)
            font.family: map.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
          Text {
            visible: body.height > Style.space(40)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: slot.isOff ? "off" : slot.d.width + " x " + slot.d.height
            color: Qt.darker(map.foreground, 1.45)
            font.family: map.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        Text {
          visible: slot.isMirror
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: Style.space(4)
          width: parent.width - Style.space(8)
          textFormat: Text.PlainText
          text: slot.d.name + " mirrors " + modelData.of
          color: Qt.darker(map.foreground, 1.3)
          font.family: map.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: slot.draggable ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
          drag.target: slot.draggable ? body : null
          drag.threshold: Style.space(5)

          onClicked: map.picked(slot.d.name)
          onPressed: map.picked(slot.d.name)

          function updateSide() {
            var a = map.anchorRect
            if (!a) return
            var cx = slot.x + body.x + slot.width / 2
            var cy = slot.y + body.y + slot.height / 2
            map.dragSide = Model.dropSide(cx - (a.px + a.pw / 2), cy - (a.py + a.ph / 2), a.pw, a.ph, slot.width, slot.height)
          }
          onPositionChanged: if (drag.active) { map.dragName = slot.d.name; updateSide() }
          onReleased: {
            if (!slot.draggable || !map.dragSide) { map.dragSide = ""; return }
            var side = map.dragSide
            map.dragSide = ""
            map.dragName = ""
            body.x = 0
            body.y = 0
            map.sideDropped(slot.d.name, side)
          }
        }
      }
    }
  }

  // Lone laptop: show where a second screen would appear.
  Rectangle {
    visible: map.displays.length === 1 && map.anchorRect !== null
    z: 0
    x: map.anchorRect ? map.anchorRect.px + map.anchorRect.pw + Style.space(10) : 0
    y: map.anchorRect ? map.anchorRect.py + map.anchorRect.ph * 0.15 : 0
    width: map.anchorRect ? map.anchorRect.pw * 0.8 : 0
    height: map.anchorRect ? map.anchorRect.ph * 0.7 : 0
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(map.foreground, 0.22)
    Text {
      anchors.centerIn: parent
      width: parent.width - Style.space(8)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      text: "plug in a screen"
      color: Qt.darker(map.foreground, 1.6)
      font.family: map.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
