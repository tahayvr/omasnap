.pragma library

// r of 0 follows the shot.
var RATIOS = [
    { key: "auto",  label: "Auto",   r: 0 },
    { key: "16:9",  label: "16:9",   r: 16 / 9 },
    { key: "4:3",   label: "4:3",    r: 4 / 3 },
    { key: "3:2",   label: "3:2",    r: 3 / 2 },
    { key: "1:1",   label: "1:1",    r: 1 },
    { key: "4:5",   label: "4:5",    r: 4 / 5 },
    { key: "9:16",  label: "9:16",   r: 9 / 16 },
    { key: "1.91",  label: "OG",     r: 1.91 }
];

// Backgrounds. `stops` is a list of colors spread evenly from one corner to
// the other, or {at, color} for a stop placed by hand. Two of them make the
// plain linear ramps; more make a gradient that turns through a colour on its
// way, which two stops cannot do.
var GRADIENT_STOPS = 5;          // slots Stage binds; presets may use fewer

var GRADIENTS = [
    { key: "dusk",     angle: 135, stops: ["#3b2f5e", "#7b5ea7"] },
    { key: "ember",    angle: 120, stops: ["#7a2e2e", "#e0764a"] },
    { key: "moss",     angle: 150, stops: ["#1f3d2b", "#5c8a58"] },
    { key: "slate",    angle: 160, stops: ["#1f2430", "#4a5568"] },
    { key: "tide",     angle: 130, stops: ["#123a5c", "#4aa6c7"] },
    { key: "sand",     angle: 110, stops: ["#8a6d3b", "#e3c391"] },
    { key: "plum",     angle: 140, stops: ["#4a1d3f", "#b0577f"] },
    { key: "rose",     angle: 125, stops: ["#6d2a44", "#e39ab0"] },
    { key: "teal",     angle: 145, stops: ["#10403f", "#57c9bd"] },
    { key: "ink",      angle: 180, stops: ["#0d0d12", "#2b2b38"] },
    { key: "aurora",   angle: 150, stops: ["#08203e", "#15756b", "#9fe0a8"] },
    { key: "sunset",   angle: 120, stops: ["#231942", "#9e3d6b", "#e8915b"] },
    { key: "nebula",   angle: 140, stops: ["#12091f", "#4a2a6b", "#9b4f8e", "#d98fb0"] },
    { key: "canyon",   angle: 125, stops: ["#2a1410", "#7d3b23", "#c97a3e", "#e8c07a"] },
    { key: "twilight", angle: 160, stops: ["#0d1b2a", "#3d5a80", "#98c1d9", "#e0fbfc"] },

    // Multipoint, or mesh: colors placed about the frame rather than
    // strung along one axis. `base` shows wherever no point reaches.
    { key: "bloom", base: "#241b3a", points: [
        { x: 0.18, y: 0.2, r: 0.75, color: "#6d4bd6" },
        { x: 0.85, y: 0.12, r: 0.7, color: "#e0567a" },
        { x: 0.75, y: 0.85, r: 0.8, color: "#f0a05a" },
        { x: 0.1, y: 0.9, r: 0.7, color: "#2ec5b6" }] },
    { key: "lagoon", base: "#06202e", points: [
        { x: 0.2, y: 0.15, r: 0.75, color: "#1c7fa8" },
        { x: 0.88, y: 0.3, r: 0.7, color: "#2ec5b6" },
        { x: 0.55, y: 0.9, r: 0.8, color: "#0f5d7a" },
        { x: 0.05, y: 0.7, r: 0.65, color: "#3fd6c4" }] },
    { key: "magma", base: "#180a06", points: [
        { x: 0.15, y: 0.85, r: 0.75, color: "#c2341c" },
        { x: 0.8, y: 0.7, r: 0.7, color: "#e8761f" },
        { x: 0.55, y: 0.15, r: 0.75, color: "#7a1f3d" },
        { x: 0.95, y: 0.05, r: 0.55, color: "#f0c040" }] },
    { key: "orchid", base: "#2a1233", points: [
        { x: 0.15, y: 0.25, r: 0.7, color: "#8a3fb0" },
        { x: 0.85, y: 0.2, r: 0.7, color: "#e06fa8" },
        { x: 0.7, y: 0.88, r: 0.75, color: "#4a5fd0" },
        { x: 0.12, y: 0.85, r: 0.65, color: "#c25f9e" }] },
    { key: "dune", base: "#2b1d14", points: [
        { x: 0.2, y: 0.2, r: 0.72, color: "#a8642c" },
        { x: 0.85, y: 0.35, r: 0.7, color: "#e0b060" },
        { x: 0.6, y: 0.9, r: 0.78, color: "#8a3f3a" },
        { x: 0.05, y: 0.8, r: 0.6, color: "#d9944f" }] },
    { key: "frost", base: "#c9d6e4", points: [
        { x: 0.2, y: 0.18, r: 0.72, color: "#eef4fb" },
        { x: 0.85, y: 0.25, r: 0.68, color: "#a9c3e0" },
        { x: 0.7, y: 0.88, r: 0.75, color: "#c7b8e8" },
        { x: 0.1, y: 0.85, r: 0.65, color: "#dce8f2" }] },
    { key: "jade", base: "#0b2018", points: [
        { x: 0.22, y: 0.2, r: 0.72, color: "#1f7a52" },
        { x: 0.85, y: 0.28, r: 0.68, color: "#5fc48a" },
        { x: 0.6, y: 0.9, r: 0.78, color: "#0f4f3a" },
        { x: 0.08, y: 0.82, r: 0.62, color: "#9ad86a" }] },
    { key: "iris", base: "#0d1030", points: [
        { x: 0.18, y: 0.22, r: 0.72, color: "#3b4fd0" },
        { x: 0.85, y: 0.18, r: 0.68, color: "#7a5fe0" },
        { x: 0.72, y: 0.85, r: 0.75, color: "#d060a8" },
        { x: 0.08, y: 0.85, r: 0.65, color: "#2a80c9" }] },
    { key: "peach", base: "#e8d5c8", points: [
        { x: 0.2, y: 0.2, r: 0.7, color: "#f6e3d2" },
        { x: 0.85, y: 0.28, r: 0.68, color: "#f0a78f" },
        { x: 0.68, y: 0.88, r: 0.75, color: "#e0798a" },
        { x: 0.08, y: 0.85, r: 0.62, color: "#f5c9a0" }] },
    { key: "cosmos", base: "#07060f", points: [
        { x: 0.25, y: 0.18, r: 0.7, color: "#4a2f8a" },
        { x: 0.82, y: 0.22, r: 0.65, color: "#1f5fa8" },
        { x: 0.65, y: 0.85, r: 0.75, color: "#a03f7a" },
        { x: 0.1, y: 0.78, r: 0.6, color: "#2f8a8a" }] }
];

var MAX_OUTPUT_SIDE = 16384;   // common GPU texture limit
var XTERM_BLACK = "#000000";

var ARROW_STYLES = [
    { key: "straight", glyph: "\u2197", label: "Straight" },
    { key: "curved",   glyph: "\u21b7", label: "Curved" },
    { key: "line",     glyph: "\u2571", label: "Line, no head" },
    { key: "double",   glyph: "\u2194", label: "A head at each end" }
];
var ARROW_BOW = 0.22;              // how far a curve leaves the straight line

function newAnnotation(kind, x, y) {
    return {
        uid: Math.random().toString(36).slice(2, 10),
        kind: kind,
        x: x, y: y, w: 0, h: 0,
        color: "",                 // "" means "use the current ink color"
        width: 3,
        style: "",                 // arrows: straight | curved | line | double
        text: "",
        index: 0,
        strength: 14               // pixelation block size for redact
    };
}

// Everything the arrow delegate draws, from the drag extents and the size of
// the head. The shaft is a quadratic curve whatever the style: with its
// control point on the midpoint it is the straight line, so one path serves
// all four. Both heads point along the curve, which at either end runs
// towards the control point, and the shaft stops short of a head so the head
// is the tip rather than sitting on top of a blunt end.
function arrowShape(w, h, style, head) {
    var aw = Math.abs(w), ah = Math.abs(h);
    var x1 = w >= 0 ? 0 : aw, y1 = h >= 0 ? 0 : ah;
    var x2 = w >= 0 ? aw : 0, y2 = h >= 0 ? ah : 0;

    var curved = style === "curved";
    var headEnd = style !== "line";
    var headStart = style === "double";

    var cx = (x1 + x2) / 2 + (curved ? (y2 - y1) * ARROW_BOW : 0);
    var cy = (y1 + y2) / 2 - (curved ? (x2 - x1) * ARROW_BOW : 0);

    var angEnd = Math.atan2(y2 - cy, x2 - cx);
    var angStart = Math.atan2(y1 - cy, x1 - cx);
    var back = head * 0.82;

    return {
        cx: cx, cy: cy,
        tailX: x1, tailY: y1,
        tipX: x2, tipY: y2,
        sx: x1 - (headStart ? Math.cos(angStart) * back : 0),
        sy: y1 - (headStart ? Math.sin(angStart) * back : 0),
        ex: x2 - (headEnd ? Math.cos(angEnd) * back : 0),
        ey: y2 - (headEnd ? Math.sin(angEnd) * back : 0),
        angStart: angStart,
        angEnd: angEnd,
        headStart: headStart,
        headEnd: headEnd
    };
}

function parseHex(hex) {
    // Eight digits is a QML colour carrying its alpha in front; the alpha
    // says nothing about what reads against it.
    var m = /^#?(?:[0-9a-fA-F]{2})?([0-9a-fA-F]{6})$/.exec(String(hex || "").trim());
    if (!m) return null;
    var n = parseInt(m[1], 16);
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
}

function toHex(r, g, b) {
    function p(v) {
        var n = Math.round(clamp(v, 0, 255)).toString(16);
        return n.length < 2 ? "0" + n : n;
    }
    return "#" + p(r) + p(g) + p(b);
}

function luminance(c) {
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

// The title bar borrows the card's own dominant color so the two read as one
// window, one step away from it so the seam is still visible: darker over a
// light card, lighter over a dark one. Near-black needs an absolute lift as
// well, because scaling it up leaves it black.
function chromeTint(hex) {
    var c = parseHex(hex);
    if (!c) return "";
    if (luminance(c) > 150) return toHex(c.r * 0.9, c.g * 0.9, c.b * 0.9);
    return toHex(c.r + (255 - c.r) * 0.1 + 14,
                 c.g + (255 - c.g) * 0.1 + 14,
                 c.b + (255 - c.b) * 0.1 + 14);
}

// Title text that stays legible on whatever chromeTint produced.
function textOn(hex) {
    var c = parseHex(hex);
    if (!c) return "#e8e8e8";
    return luminance(c) > 150 ? "#1b1b1b" : "#f0f0f0";
}

// The card is the screenshot plus the title bar above it.
function chromeHeight(doc) {
    var sh = Math.max(1, doc.shotHeight);
    if (doc.frame === "titlebar")
        return clamp(Math.round(sh * 0.045), 28, 48);
    return 0;
}

// The inset grows the card around the shot and is filled with the shot's own
// edge color, so the screenshot reads as having more room inside its window.
// Padding, by contrast, grows the frame around the whole card.
function insetSize(doc) {
    var longest = Math.max(1, doc.shotWidth, doc.shotHeight);
    return Math.max(0, Math.round((doc.inset || 0) / 100 * longest));
}

function frameGeometry(doc) {
    var sw = Math.max(1, doc.shotWidth);
    var sh = Math.max(1, doc.shotHeight);
    var chrome = chromeHeight(doc);
    var inset = insetSize(doc);

    var cardW = sw + inset * 2;
    var cardH = sh + inset * 2 + chrome;

    var pad = Math.max(0, doc.padding / 100 * Math.max(cardW, cardH));

    var w = cardW + pad * 2;
    var h = cardH + pad * 2;

    var ratio = 0;
    for (var i = 0; i < RATIOS.length; i++)
        if (RATIOS[i].key === doc.ratio) ratio = RATIOS[i].r;

    if (ratio > 0) {
        if (w / h < ratio) w = h * ratio;
        else h = w / ratio;
    }

    var x = (w - cardW) / 2;
    var y = (h - cardH) / 2;

    // Arithmetically centred content reads as sitting low; lift it a little.
    if (doc.balance && ratio > 0) {
        var slack = (h - cardH) / 2;
        y = slack - Math.min(slack * 0.18, pad * 0.5);
    }

    return {
        frameW: Math.round(w),
        frameH: Math.round(h),
        cardX: Math.round(x),
        cardY: Math.round(y),
        cardW: cardW,
        cardH: cardH,
        chromeH: chrome,
        inset: inset,
        shotW: sw,
        shotH: sh,
        pad: pad
    };
}

// grabToImage multiplies its target size by the window's device pixel ratio,
// and on a fractional ratio the stage is not a whole number of logical pixels:
// 1210 shot pixels are 756.25 of them at 1.6. Grabbing the stage at 757 would
// render it at 757/756.25 and resample every pixel, so the export grabs a
// wrapper around the stage instead, padded up to a whole number of device
// pixels, and postcard-deliver crops the surplus off. grabStep is the smallest
// run of logical pixels that is whole in device pixels: 5 at 1.6, 4 at 1.25,
// 2 at 1.5, 1 at any integer.
function grabStep(dpr) {
    var s = dpr > 0 ? dpr : 1;
    for (var k = 1; k <= 64; k++)
        if (Math.abs(k * s - Math.round(k * s)) < 1e-6) return k;
    return 1;
}

// The wrapper's size, in logical pixels, for a stage of the given size.
function grabSize(w, h, dpr) {
    var k = grabStep(dpr);
    return { w: Math.max(k, Math.ceil(w / k) * k), h: Math.max(k, Math.ceil(h / k) * k) };
}

function gradientByKey(key) {
    for (var i = 0; i < GRADIENTS.length; i++)
        if (GRADIENTS[i].key === key) return GRADIENTS[i];
    return GRADIENTS[0];
}

// The user's own gradient sits beside the presets under the key "custom";
// its stops and angle live on the document, which this library cannot see.
var CUSTOM_MIN_STOPS = 2;
var CUSTOM_MAX_STOPS = 4;
var CUSTOM_STOPS = ["#3b2f5e", "#7b5ea7"];
var CUSTOM_ANGLE = 135;

function gradientFor(key, customStops, customAngle) {
    if (key !== "custom") return gradientByKey(key);
    var stops = Array.isArray(customStops) && customStops.length >= CUSTOM_MIN_STOPS
              ? customStops.slice(0, CUSTOM_MAX_STOPS) : CUSTOM_STOPS;
    var angle = typeof customAngle === "number" && isFinite(customAngle) ? customAngle : CUSTOM_ANGLE;
    return { key: "custom", angle: Math.round(angle), stops: stops };
}

// Always GRADIENT_STOPS entries, so the stops can be bound declaratively
// rather than built at runtime. A preset with fewer repeats its last color at
// position 1, which renders identically to the shorter list.
function gradientStops(colors, angleless) {
    var raw = colors && colors.length ? colors : [];
    var out = [];
    for (var i = 0; i < raw.length; i++) {
        var s = raw[i];
        if (typeof s === "string")
            out.push({ at: raw.length < 2 ? 0 : i / (raw.length - 1), color: s });
        else if (s && s.color)
            out.push({ at: clamp(Number(s.at) || 0, 0, 1), color: String(s.color) });
    }
    if (!out.length) out.push({ at: 0, color: XTERM_BLACK });
    var last = out[out.length - 1];
    while (out.length < GRADIENT_STOPS) out.push({ at: 1, color: last.color });
    return out.slice(0, GRADIENT_STOPS);
}

// How many of the slots a preset actually uses; the README and the swatches
// want to say "three colors", not "five".
function gradientStopCount(key) {
    var g = gradientByKey(key);
    return g.stops ? g.stops.length : 0;
}

// Auto builds its ramp from one color rather than pairing the two most
// dominant ones. Those two are often unrelated — a bright logo and a dark
// terminal, say — and ramping between them drags the whole backdrop through
// muddy mid-tones, which reads as a cheap gradient however smoothly it is
// drawn. One color shaded both ways keeps the hue and stays close to the
// presets in spread.
function autoGradient(hex) {
    var c = parseHex(hex);
    if (!c) return [];
    function mix(t, target) {
        return toHex(c.r + (target - c.r) * t,
                     c.g + (target - c.g) * t,
                     c.b + (target - c.b) * t);
    }
    // A light backdrop has more room to darken than to lighten, and the other
    // way round, so the shading leans away from whichever end it sits near.
    var light = luminance(c) > 150;
    return light ? [mix(0.10, 255), mix(0.22, 0)]
                 : [mix(0.16, 0), mix(0.26, 255)];
}

// A preset is either a ramp along one axis or a set of points scattered over
// the frame. Nothing carries both.
function gradientIsMesh(g) {
    return !!(g && g.points && g.points.length);
}

// Points clamped into the frame, so a bad preset cannot push a fill off it.
function meshPoints(g) {
    var raw = (g && g.points) || [];
    var out = [];
    for (var i = 0; i < raw.length; i++) {
        var p = raw[i];
        if (!p || !p.color) continue;
        out.push({
            x: clamp(Number(p.x) || 0, -0.5, 1.5),
            y: clamp(Number(p.y) || 0, -0.5, 1.5),
            r: Math.max(0.02, Number(p.r) || 0.5),
            color: String(p.color)
        });
    }
    return out;
}

function clamp(v, lo, hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

function stamp() {
    var d = new Date();
    function p(n) { return (n < 10 ? "0" : "") + n; }
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate())
         + "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds());
}

// The save dialog hands back whatever name was typed, and magick picks its
// encoder from the extension: a name with none fails outright, and one
// carrying the other format's extension would lie about the contents.
function withExtension(path, ext) {
    var p = String(path || "");
    var dot = p.lastIndexOf(".");
    var cur = dot > p.lastIndexOf("/") + 1 ? p.slice(dot + 1).toLowerCase() : "";
    if (cur === ext || (ext === "jpg" && cur === "jpeg")) return p;
    // Only an image extension is replaced; a dot anywhere else in the name is
    // part of the name.
    var image = ["png", "jpg", "jpeg", "webp"].indexOf(cur) !== -1;
    return (image ? p.slice(0, dot) : p) + "." + ext;
}

// --- Spotlight -------------------------------------------------------------
// The dim is one filled path rather than one per spotlight: drawn separately
// they would darken twice where they overlap.

function svgN(v) { return Math.round(v * 10) / 10; }

// A rectangle with per-corner radii, as an SVG subpath.
function rectSubpath(x, y, w, h, tl, tr, br, bl) {
    var lim = Math.min(w, h) / 2;
    function r(v) { return clamp(Number(v) || 0, 0, lim); }
    tl = r(tl); tr = r(tr); br = r(br); bl = r(bl);
    var d = "M" + svgN(x + tl) + "," + svgN(y) + "H" + svgN(x + w - tr);
    if (tr) d += "A" + svgN(tr) + "," + svgN(tr) + " 0 0 1 " + svgN(x + w) + "," + svgN(y + tr);
    d += "V" + svgN(y + h - br);
    if (br) d += "A" + svgN(br) + "," + svgN(br) + " 0 0 1 " + svgN(x + w - br) + "," + svgN(y + h);
    d += "H" + svgN(x + bl);
    if (bl) d += "A" + svgN(bl) + "," + svgN(bl) + " 0 0 1 " + svgN(x) + "," + svgN(y + h - bl);
    d += "V" + svgN(y + tl);
    if (tl) d += "A" + svgN(tl) + "," + svgN(tl) + " 0 0 1 " + svgN(x + tl) + "," + svgN(y);
    return d + "Z";
}

// Two half arcs, so the ellipse closes on itself.
function ellipseSubpath(x, y, w, h) {
    var rx = svgN(w / 2), ry = svgN(h / 2), cy = svgN(y + h / 2);
    return "M" + svgN(x) + "," + cy
         + "A" + rx + "," + ry + " 0 0 1 " + svgN(x + w) + "," + cy
         + "A" + rx + "," + ry + " 0 0 1 " + svgN(x) + "," + cy + "Z";
}

// Every spotlight annotation as a normalised rectangle, moved from screenshot
// pixels into the dimmed area's own coordinates (an inset sits between them).
function spotlightHoles(model, offset, shape) {
    var out = [];
    if (!model) return out;
    var dyn = typeof model.count === "number";
    var n = dyn ? model.count : model.length;
    for (var i = 0; i < n; i++) {
        var a = dyn ? model.get(i) : model[i];
        if (!a || a.kind !== "spotlight") continue;
        out.push({
            x: Math.min(a.x, a.x + a.w) + offset,
            y: Math.min(a.y, a.y + a.h) + offset,
            w: Math.abs(a.w),
            h: Math.abs(a.h),
            shape: shape
        });
    }
    return out;
}

// The picture's outline with a hole punched for every spotlight, filled
// odd-even. A hole is clamped to the picture, and where it reaches a corner it
// takes that corner's radius: a hole reaching past the outline would be filled
// in by the odd-even rule instead of punched out, which reads as a dark wedge
// sitting outside the card.
function spotlightPath(w, h, topRadius, bottomRadius, holes) {
    var d = rectSubpath(0, 0, w, h, topRadius, topRadius, bottomRadius, bottomRadius);
    for (var i = 0; holes && i < holes.length; i++) {
        var s = holes[i];
        var x0 = clamp(Math.min(s.x, s.x + s.w), 0, w), x1 = clamp(Math.max(s.x, s.x + s.w), 0, w);
        var y0 = clamp(Math.min(s.y, s.y + s.h), 0, h), y1 = clamp(Math.max(s.y, s.y + s.h), 0, h);
        if (x1 - x0 < 1 || y1 - y0 < 1) continue;
        if (s.shape === "ellipse") {
            d += ellipseSubpath(x0, y0, x1 - x0, y1 - y0);
            continue;
        }
        d += rectSubpath(x0, y0, x1 - x0, y1 - y0,
                         x0 <= 0 && y0 <= 0 ? topRadius : 0,
                         x1 >= w && y0 <= 0 ? topRadius : 0,
                         x1 >= w && y1 >= h ? bottomRadius : 0,
                         x0 <= 0 && y1 >= h ? bottomRadius : 0);
    }
    return d;
}

// --- Crop ------------------------------------------------------------------

var MIN_CROP = 16;                 // below this it is a stray click, not a crop

// A drag normalised into the picture: it may run any way and may start or
// end outside it.
function cropRect(x, y, w, h, shotW, shotH) {
    var x0 = clamp(Math.round(Math.min(x, x + w)), 0, shotW);
    var x1 = clamp(Math.round(Math.max(x, x + w)), 0, shotW);
    var y0 = clamp(Math.round(Math.min(y, y + h)), 0, shotH);
    var y1 = clamp(Math.round(Math.max(y, y + h)), 0, shotH);
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

// QML's rect spells its size width/height; the plain objects here and in the
// path builder spell it w/h, and a rect crossing between the two reads as
// zero-sized if only one spelling is honoured.
function rectW(r) { return r.w !== undefined ? r.w : r.width; }
function rectH(r) { return r.h !== undefined ? r.h : r.height; }

function cropUsable(r) {
    return !!r && rectW(r) >= MIN_CROP && rectH(r) >= MIN_CROP;
}

// Every crop is taken from the file the editor opened rather than from the
// last crop of a crop, so the selection is offset by how far the picture has
// already moved. Re-encoding a re-encode would only lose quality.
function cropInSource(sel, offsetX, offsetY) {
    return { x: Math.round(sel.x + offsetX), y: Math.round(sel.y + offsetY),
             w: Math.round(rectW(sel)), h: Math.round(rectH(sel)) };
}

// --- Picking and resizing annotations ---------------------------------------

var MIN_ANNOTATION = 8;            // shot pixels, in either direction

function normalised(a) {
    return { x: Math.min(a.x, a.x + a.w), y: Math.min(a.y, a.y + a.h),
             w: Math.abs(a.w), h: Math.abs(a.h) };
}

// Whether a press at (px, py), in screenshot pixels, belongs to this
// annotation. A box, an ellipse and an arrow are mostly empty space, and
// taking the whole bounding box made whichever was drawn last swallow every
// press over the things inside it. `slop` is the reach in shot pixels.
function hitAnnotation(a, px, py, slop, shownW, shownH) {
    var r = normalised(a);
    // A text label is as big as its text, which only the delegate knows: its
    // own w and h are zero, and taking those meant only the very corner of a
    // label could be clicked.
    if (shownW !== undefined) r.w = shownW;
    if (shownH !== undefined) r.h = shownH;
    var stroke = Math.max(1, a.width || 1);
    var reach = slop + stroke / 2;

    // An arrow is drawn outside the box the drag made: the head's barbs stand
    // off the line, and a curve bows away from it altogether.
    var pad = reach;
    if (a.kind === "arrow") {
        pad += Math.max(10, stroke * 3.2)
             + (a.style === "curved" ? Math.max(r.w, r.h) * ARROW_BOW : 0);
    }

    if (px < r.x - pad || px > r.x + r.w + pad
        || py < r.y - pad || py > r.y + r.h + pad) return false;

    if (a.kind === "arrow") return nearArrow(a, px, py, reach);

    if (a.kind === "box") {
        // Anywhere but the hollow middle.
        return px <= r.x + reach || px >= r.x + r.w - reach
            || py <= r.y + reach || py >= r.y + r.h - reach;
    }

    if (a.kind === "ellipse") {
        var rx = Math.max(1, r.w / 2), ry = Math.max(1, r.h / 2);
        var dx = (px - (r.x + rx)) / rx, dy = (py - (r.y + ry)) / ry;
        var d = Math.sqrt(dx * dx + dy * dy);
        // The ring's thickness in these normalised units, off the shorter axis.
        var band = reach / Math.min(rx, ry);
        return d >= 1 - band && d <= 1 + band;
    }

    return true;                   // the filled kinds are their whole box
}

// The shaft is a quadratic, so it is walked rather than solved; the head is
// taken as a disc at the tip.
function nearArrow(a, px, py, reach) {
    var g = arrowShape(a.w, a.h, a.style, Math.max(10, (a.width || 1) * 3.2));
    var ox = Math.min(a.x, a.x + a.w), oy = Math.min(a.y, a.y + a.h);
    var x = px - ox, y = py - oy;
    var head = Math.max(10, (a.width || 1) * 3.2);

    if (Math.abs(x - g.tipX) <= head && Math.abs(y - g.tipY) <= head) return true;
    if (g.headStart && Math.abs(x - g.tailX) <= head && Math.abs(y - g.tailY) <= head) return true;

    var steps = 24, best = 1e9;
    for (var i = 0; i <= steps; i++) {
        var t = i / steps, u = 1 - t;
        var qx = u * u * g.sx + 2 * u * t * g.cx + t * t * g.ex;
        var qy = u * u * g.sy + 2 * u * t * g.cy + t * t * g.ey;
        var d = Math.sqrt((qx - x) * (qx - x) + (qy - y) * (qy - y));
        if (d < best) best = d;
    }
    return best <= reach;
}

var SIDE_KEYS = ["t", "r", "b", "l"];

// The points a selected annotation can be pulled by, in screenshot pixels.
// An arrow is held by its ends, everything else by the corners of its box,
// and by the middle of each side too unless it is a step badge, which has to
// stay round. A text label has no size of its own, so it has none.
function resizeHandles(a) {
    if (!a || a.kind === "text") return [];
    if (a.kind === "arrow")
        return [{ key: "tail", x: a.x, y: a.y }, { key: "tip", x: a.x + a.w, y: a.y + a.h }];
    var r = normalised(a);
    var corners = [{ key: "tl", x: r.x, y: r.y },
                   { key: "tr", x: r.x + r.w, y: r.y },
                   { key: "br", x: r.x + r.w, y: r.y + r.h },
                   { key: "bl", x: r.x, y: r.y + r.h }];
    if (a.kind === "step") return corners;
    return corners.concat([{ key: "t", x: r.x + r.w / 2, y: r.y },
                           { key: "r", x: r.x + r.w, y: r.y + r.h / 2 },
                           { key: "b", x: r.x + r.w / 2, y: r.y + r.h },
                           { key: "l", x: r.x, y: r.y + r.h / 2 }]);
}

function isSideHandle(key) {
    return SIDE_KEYS.indexOf(key) !== -1;
}

// Where an annotation lands when one of those points is dragged to (px, py).
// The edges opposite the handle stay put, a side moves its own edge only, and
// a step badge keeps its two sides equal so it stays round.
function resizeAnnotation(a, key, px, py) {
    if (a.kind === "arrow") {
        if (key === "tail")
            return { x: px, y: py, w: a.x + a.w - px, h: a.y + a.h - py };
        return { x: a.x, y: a.y, w: px - a.x, h: py - a.y };
    }

    var r = normalised(a);
    var ax = (key === "tl" || key === "bl" || key === "l") ? r.x + r.w : r.x;
    var ay = (key === "tl" || key === "tr" || key === "t") ? r.y + r.h : r.y;

    if (key === "t" || key === "b") {
        var sh = Math.max(MIN_ANNOTATION, Math.abs(py - ay));
        return { x: r.x, y: py < ay ? ay - sh : ay, w: r.w, h: sh };
    }
    if (key === "l" || key === "r") {
        var sw = Math.max(MIN_ANNOTATION, Math.abs(px - ax));
        return { x: px < ax ? ax - sw : ax, y: r.y, w: sw, h: r.h };
    }

    var w = Math.max(MIN_ANNOTATION, Math.abs(px - ax));
    var h = Math.max(MIN_ANNOTATION, Math.abs(py - ay));
    if (a.kind === "step") { w = Math.max(w, h); h = w; }

    return { x: px < ax ? ax - w : ax, y: py < ay ? ay - h : ay, w: w, h: h };
}

// Whether any of an annotation still shows inside a crop, so that what is cut
// away takes the marks that were only on it.
function overlapsRect(a, x, y, w, h) {
    var r = normalised(a);
    // A text label is a point with its text hanging off it, and a zero-sized
    // mark is still somewhere.
    var rw = Math.max(r.w, 1), rh = Math.max(r.h, 1);
    return r.x < x + w && r.x + rw > x && r.y < y + h && r.y + rh > y;
}

var CAPTURE_MODES = ["region", "windows", "fullscreen", "smart"];
var MAX_DELAY = 60;

// What `capture` was asked for. The CLI hands over one string, so a delay
// arrives inside it as {"mode","delay"} JSON; a summon passes it apart.
// An unknown mode falls back to region, as the bar always has; a delay that
// is not a whole number of seconds is refused rather than rounded.
function captureRequest(mode, delay) {
    if (typeof mode === "string" && mode.trim().indexOf("{") === 0) {
        var options;
        try { options = JSON.parse(mode); } catch (e) { return { error: "bad json" }; }
        mode = options.mode;
        delay = options.delay;
    }
    var seconds = delay === undefined ? 0 : delay;
    if (typeof seconds !== "number" || !isFinite(seconds)
            || seconds < 0 || seconds > MAX_DELAY || Math.floor(seconds) !== seconds)
        return { error: "bad delay" };
    var m = String(mode || "region");
    if (CAPTURE_MODES.indexOf(m) === -1) m = "region";
    return { mode: m, seconds: seconds };
}

// "#abc", "abc", "#aabbcc" or "AABBCC" as "#aabbcc"; anything else as "".
function normaliseHex(text) {
    var t = String(text || "").trim().replace(/^#/, "").toLowerCase();
    if (/^[0-9a-f]{3}$/.test(t)) t = t[0] + t[0] + t[1] + t[1] + t[2] + t[2];
    return /^[0-9a-f]{6}$/.test(t) ? "#" + t : "";
}

// Hue in degrees, saturation and value 0 to 1.
function hsvToHex(h, s, v) {
    h = ((h % 360) + 360) % 360;
    s = clamp(s, 0, 1);
    v = clamp(v, 0, 1);
    var c = v * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = v - c;
    var r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; }
    else if (h < 120) { r = x; g = c; }
    else if (h < 180) { g = c; b = x; }
    else if (h < 240) { g = x; b = c; }
    else if (h < 300) { r = x; b = c; }
    else { r = c; b = x; }
    return toHex(Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255));
}

// A gray has no hue of its own, so it reports the hue it was given; a picker
// set to gray then keeps its place on the hue bar.
function hexToHsv(hex, fallbackHue) {
    var c = parseHex(hex);
    if (!c) return { h: fallbackHue || 0, s: 0, v: 0 };
    var r = c.r / 255, g = c.g / 255, b = c.b / 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    var h = fallbackHue || 0;
    if (d > 0) {
        if (max === r) h = 60 * (((g - b) / d) % 6);
        else if (max === g) h = 60 * ((b - r) / d + 2);
        else h = 60 * ((r - g) / d + 4);
        if (h < 0) h += 360;
    }
    return { h: h, s: max === 0 ? 0 : d / max, v: max };
}

var CUSTOM_COLORS_KEPT = 8;

// The recent custom colors, newest first. Within one visit to the picker
// every choice replaces the one before it, so dragging about leaves one
// color behind rather than a trail; a fresh visit pushes a new one.
function rememberColor(list, hex, replaceFirst) {
    var c = normaliseHex(hex);
    var out = Array.isArray(list) ? list.slice() : [];
    if (!c) return out;
    if (replaceFirst && out.length) out.shift();
    out = out.filter(function (x) { return normaliseHex(x) !== c; });
    out.unshift(c);
    return out.slice(0, CUSTOM_COLORS_KEPT);
}

function forgetColor(list, hex) {
    var c = normaliseHex(hex);
    return (Array.isArray(list) ? list : []).filter(function (x) { return normaliseHex(x) !== c; });
}

var USER_GRADIENTS_KEPT = 12;

// A saved gradient as it may come back off disk: its stops cleaned up and
// bounded, its angle whole and in range. Null when there is not enough of a
// gradient left to draw.
function cleanGradient(g) {
    if (!g || typeof g !== "object" || !Array.isArray(g.stops)) return null;
    var stops = g.stops.map(normaliseHex).filter(function (c) { return c !== ""; });
    if (stops.length < CUSTOM_MIN_STOPS) return null;
    var angle = typeof g.angle === "number" && isFinite(g.angle) ? g.angle : CUSTOM_ANGLE;
    return {
        id: g.id ? String(g.id) : newGradientId(),
        stops: stops.slice(0, CUSTOM_MAX_STOPS),
        angle: Math.round(clamp(angle, 0, 359))
    };
}

function newGradientId() {
    return Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
}

// Edits land on the saved gradient where it already sits, so the row does
// not reshuffle under the pointer; a new one goes in front.
function saveGradient(list, g) {
    var clean = cleanGradient(g);
    var out = Array.isArray(list) ? list.slice() : [];
    if (!clean) return out;
    for (var i = 0; i < out.length; i++) {
        if (out[i].id === clean.id) { out[i] = clean; return out; }
    }
    out.unshift(clean);
    return out.slice(0, USER_GRADIENTS_KEPT);
}

function forgetGradient(list, id) {
    return (Array.isArray(list) ? list : []).filter(function (g) { return g.id !== id; });
}

// Where a new gradient of the user's starts: the one on show if it is a
// linear one, since that is usually what is about to be adjusted.
function gradientSeed(key, customStops, customAngle) {
    var g = gradientFor(key, customStops, customAngle);
    if (gradientIsMesh(g)) return { stops: CUSTOM_STOPS.slice(), angle: CUSTOM_ANGLE };
    return { stops: g.stops.slice(0, CUSTOM_MAX_STOPS), angle: g.angle !== undefined ? g.angle : CUSTOM_ANGLE };
}
