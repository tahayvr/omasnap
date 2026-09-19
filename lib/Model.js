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

var GRADIENTS = [
    { key: "dusk",    a: "#3b2f5e", b: "#7b5ea7", angle: 135 },
    { key: "ember",   a: "#7a2e2e", b: "#e0764a", angle: 120 },
    { key: "moss",    a: "#1f3d2b", b: "#5c8a58", angle: 150 },
    { key: "slate",   a: "#1f2430", b: "#4a5568", angle: 160 },
    { key: "tide",    a: "#123a5c", b: "#4aa6c7", angle: 130 },
    { key: "sand",    a: "#8a6d3b", b: "#e3c391", angle: 110 },
    { key: "plum",    a: "#4a1d3f", b: "#b0577f", angle: 140 },
    { key: "rose",    a: "#6d2a44", b: "#e39ab0", angle: 125 },
    { key: "teal",    a: "#10403f", b: "#57c9bd", angle: 145 },
    { key: "ink",     a: "#0d0d12", b: "#2b2b38", angle: 180 }
];

var MAX_OUTPUT_SIDE = 16384;   // common GPU texture limit

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
        return clamp(Math.round(sh * 0.042), 22, 44);
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

// grabToImage multiplies its target size by the window's device pixel ratio.
// Rounding can leave the file one pixel off, which beats resampling it.
function grabSize(outW, outH, dpr) {
    var s = dpr > 0 ? dpr : 1;
    return { w: Math.max(1, Math.round(outW / s)), h: Math.max(1, Math.round(outH / s)) };
}

function gradientByKey(key) {
    for (var i = 0; i < GRADIENTS.length; i++)
        if (GRADIENTS[i].key === key) return GRADIENTS[i];
    return GRADIENTS[0];
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
