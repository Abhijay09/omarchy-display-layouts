function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function normalizeScale(scale) {
  var n = parseFloat(String(scale || ""))
  if (!isFinite(n)) return ""
  return String(Math.round(n * 100) / 100)
}

function gcd(a, b) {
  while (b) {
    var remainder = a % b
    a = b
    b = remainder
  }
  return a
}

function cleanScale(scale, width, height) {
  var requested = Number(scale)
  var modeWidth = Number(width)
  var modeHeight = Number(height)
  if (!isFinite(requested) || !isFinite(modeWidth) || !isFinite(modeHeight)
      || requested <= 0 || modeWidth <= 0 || modeHeight <= 0) return ""

  var divisor = gcd(Math.round(modeWidth * 120), Math.round(modeHeight * 120))
  var scaleUnits = Math.round(requested * 120)
  if (scaleUnits > divisor) scaleUnits = divisor
  while (divisor % scaleUnits !== 0) scaleUnits++
  return normalizeScale(scaleUnits / 120)
}

function matchingScaleIndex(scales, currentScale, width, height) {
  var current = Number(currentScale)
  if (!Array.isArray(scales) || !isFinite(current)) return -1

  var bestIndex = -1
  var bestDistance = Infinity
  var normalizedCurrent = normalizeScale(current)
  for (var i = 0; i < scales.length; i++) {
    if (cleanScale(scales[i], width, height) !== normalizedCurrent) continue

    var distance = Math.abs(Number(scales[i]) - current)
    if (distance < bestDistance) {
      bestIndex = i
      bestDistance = distance
    }
  }
  return bestIndex
}

function availableScales(scales, width, height) {
  if (!Array.isArray(scales) || Number(width) <= 0 || Number(height) <= 0) return scales || []

  var byEffectiveScale = {}
  for (var i = 0; i < scales.length; i++) {
    var requested = Number(scales[i])
    var effective = Number(cleanScale(requested, width, height))

    if (!isFinite(requested) || !isFinite(effective)) continue

    var key = normalizeScale(effective)
    var existing = byEffectiveScale[key]
    if (!existing || Math.abs(requested - effective) < existing.distance) {
      byEffectiveScale[key] = {
        value: String(scales[i]),
        index: i,
        distance: Math.abs(requested - effective)
      }
    }
  }

  return Object.keys(byEffectiveScale)
    .map(function(key) { return byEffectiveScale[key] })
    .sort(function(a, b) { return a.index - b.index })
    .map(function(candidate) { return candidate.value })
}

function brightnessName(percent) {
  var p = Math.round(percent)
  if (p >= 95) return "Sun blast"
  if (p >= 80) return "Solar flare"
  if (p >= 65) return "Golden hour"
  if (p >= 45) return "Even day"
  if (p >= 30) return "Soft glow"
  if (p >= 20) return "Lamp light"
  if (p >= 10) return "Candlelit"
  return "Night owl"
}

function parseDisplays(raw) {
  var displays = []
  try {
    displays = raw ? JSON.parse(String(raw)) : []
  } catch (e) {
    displays = []
  }
  if (!Array.isArray(displays)) displays = []

  var count = 0
  for (var i = 0; i < displays.length; i++) {
    if (displays[i] && displays[i].enabled) count++
  }

  return {
    displays: displays,
    enabledDisplayCount: count
  }
}

// ---- Arrangement model (hyprctl monitors all -j) ----

var INTERNAL_RE = /^(eDP|LVDS|DSI)-/

// "Samsung Electric Company U32R5 H4ZR600109" -> "Samsung U32R5". The make is
// shortened to its first word and the trailing serial dropped, so the label
// fits inside a small rectangle on the arrangement map.
function friendlyName(description, name) {
  var d = String(description || "").replace(/\s*\([^)]*\)\s*$/, "").trim()
  if (d === "") return String(name || "")
  var words = d.split(/\s+/)
  var make = words[0]
  var rest = words.slice(1).filter(function(w) {
    return !/^(Electric|Company|Corp\.?|Corporation|Co\.?,?|Ltd\.?|Inc\.?|Display|Computer)$/i.test(w)
  })
  if (rest.length > 1 && /^[A-Z0-9]{9,}$/.test(rest[rest.length - 1])) rest.pop()
  return (make + " " + rest.join(" ")).trim()
}

function parseMonitors(raw) {
  var data = []
  try { data = raw ? JSON.parse(String(raw)) : [] } catch (e) { data = [] }
  if (!Array.isArray(data)) data = []

  var list = []
  for (var i = 0; i < data.length; i++) {
    var m = data[i]
    if (!m || !m.name) continue
    var scale = Number(m.scale) > 0 ? Number(m.scale) : 1
    var rotated = (Number(m.transform) % 2) === 1
    var w = Number(m.width) || 0
    var h = Number(m.height) || 0
    list.push({
      name: String(m.name),
      description: String(m.description || ""),
      label: friendlyName(m.description, m.name),
      internal: INTERNAL_RE.test(String(m.name)),
      enabled: m.disabled !== true,
      mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? String(m.mirrorOf) : "",
      focused: m.focused === true,
      x: Number(m.x) || 0,
      y: Number(m.y) || 0,
      width: w,
      height: h,
      scale: scale,
      transform: Number(m.transform) || 0,
      refresh: Math.round((Number(m.refreshRate) || 0) * 100) / 100,
      // Logical size on the desktop: pixels / scale, swapped when rotated.
      lw: (rotated ? h : w) / scale,
      lh: (rotated ? w : h) / scale,
      modes: modeOptions(m.availableModes, w, h, m.refreshRate)
    })
  }
  return list
}

// ["2560x1600@240.00Hz", ...] -> [{value:"2560x1600@240.00", label:"2560 x 1600  240 Hz"}]
// Sorted largest first, highest refresh first, duplicates dropped.
function modeOptions(modes, curW, curH, curRate) {
  var seen = {}
  var out = []
  var src = Array.isArray(modes) ? modes.slice() : []
  if (src.length === 0 && curW > 0) src.push(curW + "x" + curH + "@" + curRate + "Hz")
  for (var i = 0; i < src.length; i++) {
    var m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(String(src[i]))
    if (!m) continue
    var rate = Math.round(parseFloat(m[3]) * 100) / 100
    var value = m[1] + "x" + m[2] + "@" + rate.toFixed(2)
    if (seen[value]) continue
    seen[value] = true
    out.push({ w: parseInt(m[1], 10), h: parseInt(m[2], 10), rate: rate, value: value,
               label: m[1] + " x " + m[2] + "   " + Math.round(rate) + " Hz" })
  }
  out.sort(function(a, b) { return (b.w * b.h - a.w * a.h) || (b.rate - a.rate) })
  return out
}

function currentModeValue(mon) {
  return mon.width + "x" + mon.height + "@" + (Math.round(mon.refresh * 100) / 100).toFixed(2)
}

// "extend" | "mirror" | "internal" | "external" | "single" (nothing to arrange)
function layoutMode(list) {
  var internal = null, externals = []
  for (var i = 0; i < list.length; i++) {
    if (list[i].internal) internal = list[i]
    else externals.push(list[i])
  }
  if (externals.length === 0) return "single"
  for (var j = 0; j < list.length; j++) if (list[j].mirrorOf !== "") return "mirror"
  var extOn = externals.some(function(e) { return e.enabled })
  var intOn = internal && internal.enabled
  if (intOn && extOn) return "extend"
  if (!intOn && extOn) return "external"
  return "internal"
}

// Which side of the anchor (laptop screen, else first enabled) the other sits on.
function sideOf(mon, anchor) {
  if (!mon || !anchor) return "right"
  var dx = (mon.x + mon.lw / 2) - (anchor.x + anchor.lw / 2)
  var dy = (mon.y + mon.lh / 2) - (anchor.y + anchor.lh / 2)
  if (Math.abs(dx) >= Math.abs(dy)) return dx >= 0 ? "right" : "left"
  return dy >= 0 ? "down" : "up"
}

// Pick the side a dragged rectangle was dropped on. Offsets are normalised by
// the two rectangles' half-extents so a wide screen doesn't always win.
function dropSide(dx, dy, aw, ah, dw, dh) {
  var nx = dx / Math.max(1, (aw + dw) / 2)
  var ny = dy / Math.max(1, (ah + dh) / 2)
  if (Math.abs(nx) >= Math.abs(ny)) return nx >= 0 ? "right" : "left"
  return ny >= 0 ? "down" : "up"
}

if (typeof module !== "undefined") {
  module.exports = {
    clampBrightness: clampBrightness,
    normalizeScale: normalizeScale,
    cleanScale: cleanScale,
    matchingScaleIndex: matchingScaleIndex,
    availableScales: availableScales,
    brightnessName: brightnessName,
    parseDisplays: parseDisplays,
    friendlyName: friendlyName,
    parseMonitors: parseMonitors,
    modeOptions: modeOptions,
    currentModeValue: currentModeValue,
    layoutMode: layoutMode,
    sideOf: sideOf,
    dropSide: dropSide
  }
}
