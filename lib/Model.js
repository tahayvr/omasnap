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

function newAnnotation(kind, x, y) {
    return {
        uid: Math.random().toString(36).slice(2, 10),
        kind: kind,
        x: x, y: y, w: 0, h: 0,
        color: "",                 // "" means "use the current ink color"
        width: 3,
        text: "",
        index: 0,
        strength: 14               // pixelation block size for redact
    };
}

function parseHex(hex) {
    var m = /^#?([0-9a-fA-F]{6})$/.exec(String(hex || "").trim());
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
// pixels, and snap-deliver crops the surplus off. grabStep is the smallest
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
