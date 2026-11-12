// Run with: node test/model.test.js
const assert = require("node:assert")
const M = require("../Model.js")

const mon = (o) => Object.assign({
  name: "eDP-1", description: "", width: 2560, height: 1600, refreshRate: 240, x: 0, y: 0,
  scale: 2, transform: 0, disabled: false, mirrorOf: "none", focused: false, availableModes: []
}, o)

// friendly names
assert.strictEqual(M.friendlyName("Samsung Electric Company U32R5 H4ZR600109", "HDMI-A-1"), "Samsung U32R5")
assert.strictEqual(M.friendlyName("Apple Computer Inc Color LCD", "eDP-1"), "Apple Color LCD")
assert.strictEqual(M.friendlyName("", "DP-2"), "DP-2")

// logical size follows scale and rotation
let [a, b] = M.parseMonitors(JSON.stringify([mon({ name: "eDP-1" }), mon({ name: "HDMI-A-1", width: 3840, height: 2160, scale: 1.5, transform: 1 })]))
assert.deepStrictEqual([a.lw, a.lh], [1280, 800])
assert.deepStrictEqual([b.lw, b.lh], [1440, 2560])
assert.strictEqual(a.internal, true)
assert.strictEqual(b.internal, false)

// mode list: parsed, de-duplicated, biggest first
const modes = M.modeOptions(["1920x1080@60.00Hz", "2560x1600@240.00Hz", "1920x1080@60.00Hz", "2560x1600@60.00Hz", "junk"], 0, 0, 0)
assert.deepStrictEqual(modes.map((m) => m.value), ["2560x1600@240.00", "2560x1600@60.00", "1920x1080@60.00"])
assert.strictEqual(modes[0].label, "2560 x 1600   240 Hz")

// layout state
const L = (...xs) => M.parseMonitors(JSON.stringify(xs))
assert.strictEqual(M.layoutMode(L(mon({}))), "single")
assert.strictEqual(M.layoutMode(L(mon({}), mon({ name: "HDMI-A-1" }))), "extend")
assert.strictEqual(M.layoutMode(L(mon({}), mon({ name: "HDMI-A-1", mirrorOf: "0" }))), "mirror")
assert.strictEqual(M.layoutMode(L(mon({ disabled: true }), mon({ name: "HDMI-A-1" }))), "external")
assert.strictEqual(M.layoutMode(L(mon({}), mon({ name: "HDMI-A-1", disabled: true }))), "internal")

// which side a screen sits on
const [lap, tv] = L(mon({}), mon({ name: "HDMI-A-1", x: 1280, width: 1920, height: 1080, scale: 1 }))
assert.strictEqual(M.sideOf(tv, lap), "right")
assert.strictEqual(M.sideOf(Object.assign({}, tv, { x: -1920 }), lap), "left")
assert.strictEqual(M.sideOf(Object.assign({}, tv, { x: 0, y: -1080 }), lap), "up")
assert.strictEqual(M.sideOf(Object.assign({}, tv, { x: 0, y: 800 }), lap), "down")

// drag drop: offsets are normalised so a wide screen does not always win
assert.strictEqual(M.dropSide(300, 10, 200, 120, 160, 90), "right")
assert.strictEqual(M.dropSide(-300, 40, 200, 120, 160, 90), "left")
assert.strictEqual(M.dropSide(-20, -200, 200, 120, 160, 90), "up")
assert.strictEqual(M.dropSide(15, 150, 200, 120, 160, 90), "down")

console.log("model tests passed")
