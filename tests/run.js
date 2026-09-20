#!/usr/bin/env node
// Unit tests for the two JavaScript libraries. Run with `node tests/run.js`.
// The libraries are QML `.pragma library` files, so they are evaluated in a
// bare VM context rather than required as modules.
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

function lib(name) {
    const file = path.join(__dirname, "..", "lib", name);
    const src = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*/, "");
    const ctx = vm.createContext({ Math, Date, RegExp, String, Number, Array, Object,
                                   JSON, parseInt, parseFloat, isNaN, isFinite });
    vm.runInContext(src, ctx, { filename: file });
    return ctx;
}

const Model = lib("Model.js");
const Redact = lib("Redact.js");
const Code = lib("Code.js");

let passed = 0, failed = 0;
function test(name, fn) {
    try { fn(); passed++; }
    catch (e) { failed++; console.log("FAIL  " + name + "\n      " + (e.stack || e).toString().split("\n").slice(0, 2).join("\n      ")); }
}
function eq(actual, expected, what) {
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error((what || "value") + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
}
function ok(cond, what) { if (!cond) throw new Error(what || "expected truthy"); }
function near(a, b, tol, what) { if (Math.abs(a - b) > tol) throw new Error((what || "value") + ": " + a + " not within " + tol + " of " + b); }

// ---------------------------------------------------------------- Model.js

const base = { shotWidth: 1000, shotHeight: 500, padding: 10, ratio: "auto", balance: true, frame: "none" };

test("auto ratio pads by a percentage of the longest edge", () => {
    const g = Model.frameGeometry(base);
    eq(g.pad, 100, "pad");
    eq([g.frameW, g.frameH], [1200, 700], "frame");
    eq([g.cardX, g.cardY], [100, 100], "card origin");
    eq([g.cardW, g.cardH, g.chromeH], [1000, 500, 0], "card size");
});

test("zero padding hugs the shot", () => {
    const g = Model.frameGeometry(Object.assign({}, base, { padding: 0 }));
    eq([g.frameW, g.frameH, g.cardX, g.cardY], [1000, 500, 0, 0]);
});

test("a fixed ratio widens or heightens the frame, never crops", () => {
    const sq = Model.frameGeometry(Object.assign({}, base, { ratio: "1:1", balance: false }));
    eq([sq.frameW, sq.frameH], [1200, 1200], "1:1 frame");
    eq(sq.cardX, 100, "horizontally centred");
    eq(sq.cardY, 350, "vertically centred");
    const wide = Model.frameGeometry({ shotWidth: 400, shotHeight: 800, padding: 0, ratio: "16:9", balance: false, frame: "none" });
    near(wide.frameW / wide.frameH, 16 / 9, 0.01, "16:9");
    ok(wide.frameW >= 400 && wide.frameH >= 800, "shot still fits");
});

test("optical balance lifts the card only when there is slack", () => {
    const centred = Model.frameGeometry(Object.assign({}, base, { ratio: "1:1", balance: false }));
    const lifted = Model.frameGeometry(Object.assign({}, base, { ratio: "1:1", balance: true }));
    ok(lifted.cardY < centred.cardY, "lifted above centre");
    ok(lifted.cardY > 0, "still inside the frame");
    const auto = Model.frameGeometry(base);
    eq(auto.cardY, 100, "no lift in auto ratio");
});

test("the title bar is inside the card and the frame", () => {
    const g = Model.frameGeometry(Object.assign({}, base, { frame: "titlebar" }));
    ok(g.chromeH >= 28 && g.chromeH <= 48, "chrome clamped");
    eq(g.cardH, 500 + g.chromeH, "card grows");
    eq(g.frameH, 700 + g.chromeH, "frame grows");
    eq(Model.frameGeometry(Object.assign({}, base, { frame: "none" })).chromeH, 0);
    eq(Model.chromeHeight({ shotHeight: 1000, frame: "dots" }), 0, "no window frame any more");
});

test("chrome scales with the shot but stays legible", () => {
    eq(Model.chromeHeight({ shotHeight: 100, frame: "titlebar" }), 28, "small shot");
    eq(Model.chromeHeight({ shotHeight: 4000, frame: "titlebar" }), 48, "huge shot");
    eq(Model.chromeHeight({ shotHeight: 1000, frame: "titlebar" }), 45, "proportional");
});

test("the inset grows the card around the shot", () => {
    const g = Model.frameGeometry(Object.assign({}, base, { inset: 5 }));
    eq(g.inset, 50, "5% of the longest edge");
    eq(g.cardW, 1000 + 100, "card widened both sides");
    eq(g.cardH, 500 + 100, "card heightened both sides");
    eq(g.shotW, 1000, "the shot itself is untouched");
    eq(g.shotH, 500, "the shot itself is untouched");
    // The title bar sits above the inset, not inside it.
    const t = Model.frameGeometry(Object.assign({}, base, { inset: 5, frame: "titlebar" }));
    eq(t.cardH, 500 + 100 + t.chromeH, "chrome adds on top of the inset");
    eq(Model.frameGeometry(base).inset, 0, "no inset by default");
    eq(Model.insetSize({ shotWidth: 0, shotHeight: 0, inset: 10 }), 0, "empty document");
    eq(Model.insetSize({ shotWidth: 800, shotHeight: 500 }), 0, "missing property");
});

test("the title bar tints itself from the card underneath", () => {
    const dark = Model.chromeTint("#1e222a");
    const light = Model.chromeTint("#eef1f4");
    ok(Model.luminance(Model.parseHex(dark)) > Model.luminance(Model.parseHex("#1e222a")),
       "lifted off a dark card");
    ok(Model.luminance(Model.parseHex(light)) < Model.luminance(Model.parseHex("#eef1f4")),
       "deepened on a light card");
    ok(Model.luminance(Model.parseHex(Model.chromeTint("#000000"))) > 20,
       "black still separates from the card");
    // The tint keeps the card's hue, which is the whole point of sampling it.
    const blue = Model.parseHex(Model.chromeTint("#204060"));
    ok(blue.b > blue.r, "hue survives the tint");
    eq(Model.chromeTint("not a color"), "", "garbage falls through to the caller");
    eq(Model.textOn("#eef1f4"), "#1b1b1b", "dark text on a light bar");
    eq(Model.textOn("#1e222a"), "#f0f0f0", "light text on a dark bar");
    eq(Model.textOn(""), "#e8e8e8", "a readable default with no color");
});

test("geometry survives an empty document", () => {
    const g = Model.frameGeometry({ shotWidth: 0, shotHeight: 0, padding: 5, ratio: "auto", balance: true, frame: "none" });
    ok(g.frameW >= 1 && g.frameH >= 1);
});

test("gradients and ratios resolve by key with a safe default", () => {
    eq(Model.gradientByKey("moss").stops[0], "#1f3d2b");
    eq(Model.gradientByKey("nope").key, Model.GRADIENTS[0].key);
    ok(Model.RATIOS.some(r => r.key === "auto" && r.r === 0));
});

test("annotations carry every role the delegates read", () => {
    const a = Model.newAnnotation("box", 3, 4);
    for (const k of ["uid", "kind", "x", "y", "w", "h", "color", "width", "text", "index", "strength"])
        ok(k in a, "missing role " + k);
    ok(a.uid.length >= 6 && a.uid !== Model.newAnnotation("box", 0, 0).uid, "unique ids");
});

test("grab size pads the stage to whole device pixels", () => {
    eq(Model.grabStep(1.6), 5);
    eq(Model.grabStep(1.25), 4);
    eq(Model.grabStep(1.5), 2);
    eq(Model.grabStep(2), 1);
    eq(Model.grabStep(0), 1, "bad dpr falls back to 1");
    eq(Model.grabSize(756.25, 393.75, 1.6), { w: 760, h: 395 }, "padded up to whole device pixels");
    eq(Model.grabSize(300, 175, 1.6), { w: 300, h: 175 }, "already whole");
    eq(Model.grabSize(1920, 1080, 2), { w: 1920, h: 1080 });
    eq(Model.grabSize(0.5, 0.5, 1.6), { w: 5, h: 5 }, "never zero");
});

test("clamp and stamp", () => {
    eq([Model.clamp(5, 0, 3), Model.clamp(-1, 0, 3), Model.clamp(2, 0, 3)], [3, 0, 2]);
    ok(/^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/.test(Model.stamp()), "stamp format");
    ok(Model.MAX_OUTPUT_SIDE >= 8192);
});

// --------------------------------------------------------------- Redact.js

// Builds the TSV tesseract --psm 11 emits, one word per token, all on one
// line unless a token is "\n".
function tsv(text, opts) {
    const conf = (opts && opts.conf) || 95;
    let rows = ["level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext"];
    let line = 1, x = 10, word = 1;
    for (const tok of text.split(" ")) {
        if (tok === "\n") { line++; x = 10; word = 1; continue; }
        const w = tok.length * 9;
        rows.push(["5", "1", "1", "1", String(line), String(word++), String(x), String(line * 30), String(w), "18", String(conf), tok].join("\t"));
        x += w + 9;
    }
    return rows.join("\n") + "\n";
}
const ALL = Redact.CLASSES.map(c => c.key);
function labels(found) { return Object.keys(found.counts).sort(); }

test("luhn accepts real card numbers and rejects look-alikes", () => {
    ok(Redact.luhn("4111 1111 1111 1111"));
    ok(Redact.luhn("5500-0000-0000-0004"));
    ok(!Redact.luhn("4111 1111 1111 1112"));
    ok(!Redact.luhn("1234567812345678"));
    ok(!Redact.luhn("411111111111"), "too short");
});

test("ip guard skips versions, loopback and the unspecified address", () => {
    ok(Redact.plausibleIp("192.168.1.100"));
    ok(Redact.plausibleIp("10.0.0.1"));
    ok(!Redact.plausibleIp("1.2.3.4"), "version string");
    ok(!Redact.plausibleIp("127.0.0.1"));
    ok(!Redact.plausibleIp("0.0.0.0"));
    ok(!Redact.plausibleIp("300.1.1.1"), "octet out of range");
});

test("phone guard skips timestamps and dotted quads", () => {
    ok(Redact.plausiblePhone("+1 (555) 123-4567"));
    ok(Redact.plausiblePhone("020 7946 0958"));
    ok(!Redact.plausiblePhone("2026-09-19 06"), "date + hour");
    ok(!Redact.plausiblePhone("192.168.1.100"), "ip");
    ok(!Redact.plausiblePhone("12345678"), "too short");
});

test("entropy guard flags secrets, not hashes or prose", () => {
    ok(Redact.looksRandom("ghp_Ab3dE9fGh1JkLmN0pQrStUvWxYz2345678"));
    ok(!Redact.looksRandom("d41d8cd98f00b204e9800998ecf8427e"), "md5 hex is too regular");
    ok(!Redact.looksRandom("supercalifragilisticexpialidocious"), "no digits");
    ok(!Redact.looksRandom("abc"), "short");
});

test("an email is found and boxed to the word that holds it", () => {
    const found = Redact.findSensitive(tsv("Contact john.doe@example.com today"), ALL);
    eq(found.boxes.length, 1);
    eq(found.boxes[0].label, "email");
    const b = found.boxes[0];
    // second word starts at x = 10 + 7*9 + 9 = 82, width 20*9 = 180
    ok(b.x < 82 && b.x + b.w > 82 + 180, "box covers the word with padding");
    ok(b.y < 30 && b.y + b.h > 48, "box covers the line height");
});

test("a match inside a longer word is narrowed to its characters", () => {
    // One OCR word of 32 chars at x = 10, width 288: the email starts at char 12.
    const found = Redact.findSensitive(tsv("ADMIN_EMAIL=john.doe@example.com"), ALL);
    eq(found.boxes.length, 1);
    const b = found.boxes[0];
    ok(b.x > 10 + 288 * 0.3 && b.x < 10 + 288 * 0.4, "starts after the label, got x=" + b.x);
    ok(b.x + b.w > 10 + 288 - 8, "runs to the end of the word");
    // A misread character ends the pattern early; the box must still cover the whole word.
    const word = "KEY=sk-ant-api03-Zx9Qw2Lm8Np4Rt6\u00e9Yu1Io3Pa5Sd7Fg0Hj2Kl4Zx9Qw2";
    const cut = Redact.findSensitive(tsv(word), ALL);
    eq(cut.boxes.length, 1);
    ok(cut.boxes[0].x + cut.boxes[0].w > 10 + word.length * 9 - 8, "no visible tail after a misread");
});

test("a card number split across OCR words is boxed as one span", () => {
    const found = Redact.findSensitive(tsv("card 4111 1111 1111 1111 ok"), ALL);
    eq(found.boxes.length, 1, "one box, not one per word or one per pattern");
    eq(labels(found), ["card number"]);
    const b = found.boxes[0];
    // "card" is 36px wide, so the groups run from x = 55 to x = 226.
    ok(b.x < 55 && b.x + b.w > 226, "spans the four groups");
    eq(Redact.summarize(found.counts), "Hid 1 card number");
});

test("keys and tokens", () => {
    const key = "sk-ant-api03-Zx9Qw2Lm8Np4Rt6Yu1Io3Pa5Sd7Fg0Hj2Kl4Zx9Qw2Lm8Np4Rt6Yu";
    const jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
    const found = Redact.findSensitive(tsv("token " + key + " and " + jwt + " and AKIAIOSFODNN7EXAMPLE and ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123"), ALL);
    eq(found.boxes.length, 4, "four secrets, deduped across overlapping patterns");
    ok(found.counts["API key"] >= 1, "sk key labelled as API key");
    ok(found.counts["AWS key"] === 1);
    ok(found.counts["token"] >= 2, "jwt and github token");
});

test("plain prose, versions, timestamps and hashes are left alone", () => {
    const found = Redact.findSensitive(tsv("Built v1.2.3.4 at 2026-09-19 06:09:00 commit d41d8cd98f00b204e9800998ecf8427e on 127.0.0.1 with 12 items"), ALL);
    eq(found.boxes, [], "no false positives");
    eq(Redact.summarize(found.counts), "Nothing sensitive found");
});

test("ip and phone", () => {
    const found = Redact.findSensitive(tsv("host 192.168.1.100 tel +1 (555) 123-4567"), ALL);
    eq(labels(found), ["IP address", "phone"]);
    eq(found.boxes.length, 2);
});

test("switching a class off suppresses it, and nothing else picks it up", () => {
    const noNet = Redact.findSensitive(tsv("host 192.168.1.100 tel +1 (555) 123-4567"), ALL.filter(k => k !== "net"));
    eq(labels(noNet), ["phone"], "ip gone, not re-flagged as a phone");
    const noSecrets = Redact.findSensitive(tsv("mail a@b.io key ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123"), ["email"]);
    eq(labels(noSecrets), ["email"]);
    eq(Redact.findSensitive(tsv("mail a@b.io"), []).boxes, []);
});

test("low-confidence words are ignored unless long enough to be a secret", () => {
    eq(Redact.findSensitive(tsv("mail a@b.io", { conf: 20 }), ALL).boxes, []);
    const found = Redact.findSensitive(tsv("KEY=sk-ant-api03-Zx9Qw2Lm8Np4Rt6Yu1Io3Pa5Sd7Fg0Hj2Kl4Zx9Qw2", { conf: 4 }), ALL);
    eq(labels(found), ["API key"]);
});

test("matches never cross OCR lines", () => {
    // Each half is harmless on its own; joined they would form a card number.
    const found = Redact.findSensitive(tsv("4111 1111 \n 1111 1111"), ALL);
    eq(found.boxes, []);
});

test("summary reads like a sentence", () => {
    eq(Redact.summarize({ email: 2, token: 1 }), "Hid 2 emails and 1 token");
    eq(Redact.summarize({ email: 1, token: 1, "IP address": 3 }), "Hid 1 email, 1 token and 3 IP addresss");
});

test("dedupe keeps the larger box and drops the one it swallows", () => {
    const kept = Redact.dedupe([
        { x: 0, y: 0, w: 100, h: 20, label: "token" },
        { x: 10, y: 2, w: 40, h: 16, label: "email" },
        { x: 200, y: 0, w: 50, h: 20, label: "phone" }
    ]);
    eq(kept.map(b => b.label), ["token", "phone"]);
});

// ----------------------------------------------------------------- Code.js

const pal = Code.defaultPalette("#eeeeee");
const ESC = "\x1b[";

test("truecolor runs become font tags, spaces and newlines survive", () => {
    const html = Code.ansiToHtml(ESC + "38;2;255;0;0mfn" + ESC + "0m main()\n  x\n", pal);
    eq(html, '<font color="#ff0000">fn</font>&nbsp;main()<br>&nbsp;&nbsp;x');
});

test("16-color codes go through the palette, 256-color through the cube", () => {
    const html = Code.ansiToHtml(ESC + "35mkw" + ESC + "0m " + ESC + "38;5;238mnum" + ESC + "0m " + ESC + "38;5;196mr", pal);
    eq(html, '<font color="' + pal.colors[5] + '">kw</font>&nbsp;<font color="#444444">num</font>&nbsp;<font color="#ff0000">r</font>');
    eq(Code.color256(15, pal), pal.colors[15]);
    eq(Code.color256(16, pal), "#000000");
    eq(Code.color256(231, pal), "#ffffff");
});

test("bold, italic and underline nest and reset", () => {
    eq(Code.ansiToHtml(ESC + "1m" + ESC + "3ma" + ESC + "23mb" + ESC + "0mc", pal), "<b><i>a</i></b><b>b</b>c");
    eq(Code.ansiToHtml(ESC + "4mu" + ESC + "24mv", pal), "<u>u</u>v");
});

test("html is escaped and tabs expand", () => {
    eq(Code.ansiToHtml("<a & b>\tc", pal), "&lt;a&nbsp;&amp;&nbsp;b&gt;&nbsp;&nbsp;&nbsp;&nbsp;c");
});

test("non-SGR escapes are dropped and trailing newlines trimmed", () => {
    eq(Code.ansiToHtml(ESC + "Kx" + ESC + "2Jy\n\n", pal), "xy");
    eq(Code.lineCount("a\nb\n\n"), 2);
    eq(Code.lineCount(""), 0);
});

test("the omarchy palette comes from colors.toml with sensible fallbacks", () => {
    const p = Code.paletteFromTheme("background=#111C18\nforeground=#C1C497\nred=#FF5345\nmuted=#53685B\nbright_red=#DB9F9C\n", "#ffffff");
    eq([p.bg, p.fg, p.colors[0], p.colors[1], p.colors[7], p.colors[8], p.colors[9]],
       ["#111c18", "#c1c497", "#111c18", "#ff5345", "#c1c497", "#53685b", "#db9f9c"]);
    eq(p.colors[2], Code.XTERM[2], "missing color falls back to xterm");
    eq(Code.paletteFromTheme("", "#abcdef").fg, "#abcdef");
});

test("language guessing", () => {
    const cases = {
        rs:   "pub fn main() {\n    let mut x = 1;\n}",
        go:   "package main\n\nfunc main() {\n\tx := 1\n}",
        py:   "import os\n\ndef main():\n    print(os.getcwd())",
        js:   "const x = require('fs');\nexport default () => x;",
        ts:   "interface User { name: string }\nconst u: User = { name: 'a' };",
        json: "{\"a\": [1, 2], \"b\": null}",
        sh:   "#!/bin/bash\nfor f in *; do echo \"$f\"; done",
        c:    "#include <stdio.h>\nint main(void) { return 0; }",
        cpp:  "#include <iostream>\nint main() { std::cout << 1; }",
        sql:  "SELECT id, name FROM users WHERE id = 1;",
        yaml: "name: omasnap\nversion: 1\nkinds:\n  - overlay",
        toml: "[package]\nname = \"omasnap\"",
        css:  ".card { color: red; margin: 0; }",
        html: "<div class=\"x\"><span>hi</span></div>",
        md:   "# Title\n\nSome text\n\n```sh\nls\n```",
        lua:  "local function f(x)\n  return x\nend",
        java: "public class A { public static void main(String[] a) { System.out.println(1); } }",
        cs:   "using System;\nnamespace X { public class A { } }",
        txt:  "Just a sentence with nothing in particular."
    };
    for (const k in cases) eq(Code.guessLanguage(cases[k]), k, "guess for " + k);
});

test("a gradient always yields the same number of stops", () => {
    const n = Model.GRADIENT_STOPS;

    // Two colors: the pair, then the tail repeating the last one at the end,
    // which renders the same as a two-stop gradient.
    const two = Model.gradientStops(Model.gradientByKey("dusk").stops);
    eq(two.length, n, "padded to the slot count");
    eq(two[0].at, 0); eq(two[0].color, "#3b2f5e");
    eq(two[1].at, 1); eq(two[1].color, "#7b5ea7");
    ok(two.slice(2).every(s => s.at === 1 && s.color === "#7b5ea7"), "tail repeats");

    // Three and four colors spread evenly across the whole run.
    const three = Model.gradientStops(Model.gradientByKey("aurora").stops);
    eq(three.length, n);
    eq(three[1].at, 0.5, "middle color sits halfway");
    eq(three[2].color, "#9fe0a8", "and the last one lands at the end");
    const four = Model.gradientStops(Model.gradientByKey("nebula").stops);
    eq(Math.round(four[1].at * 100) / 100, 0.33);
    eq(Math.round(four[2].at * 100) / 100, 0.67);

    // A hand-placed stop keeps its position, and is clamped into range.
    const hand = Model.gradientStops([{ at: 0, color: "#000000" },
                                      { at: 0.2, color: "#ff0000" },
                                      { at: 4, color: "#ffffff" }]);
    eq(hand[1].at, 0.2, "kept where it was put");
    eq(hand[2].at, 1, "and clamped");

    // Degenerate input still fills every slot, or the stage's bindings break.
    eq(Model.gradientStops([]).length, n, "nothing at all");
    eq(Model.gradientStops(["#123456"]).length, n, "a single color");
    eq(Model.gradientStops(["#123456"])[0].at, 0);
    ok(Model.gradientStops(["#123456"]).every(s => s.color === "#123456"));

    const linear = Model.GRADIENTS.filter(g => !Model.gradientIsMesh(g));
    ok(linear.some(g => g.stops.length > 2), "some presets turn through a color");
    ok(linear.every(g => g.stops.length <= n), "and none exceeds the slots");
    eq(Model.gradientStopCount("aurora"), 3);
    eq(Model.gradientStopCount("dusk"), 2);
});

test("auto shades one color instead of pairing two dominants", () => {
    const lum = h => Model.luminance(Model.parseHex(h));
    const spread = (a, b) => {
        const p = Model.parseHex(a), q = Model.parseHex(b);
        return Math.round(Math.hypot(p.r - q.r, p.g - q.g, p.b - q.b));
    };

    const dark = Model.autoGradient("#1e1e24");
    eq(dark.length, 2, "two stops");
    ok(lum(dark[0]) < lum(dark[1]), "a dark source lifts rather than darkens");
    ok(lum(dark[1]) < 140, "and stays on the dark side of the range");

    const light = Model.autoGradient("#eceef0");
    ok(lum(light[0]) > lum(light[1]), "a light source darkens rather than lifts");
    ok(lum(light[1]) > 120, "and stays on the light side");

    // The whole point: the hue survives, because both stops come from the
    // same color. Pairing two dominants used to drag a blue backdrop through
    // olive on its way to a green one.
    const blue = Model.autoGradient("#203141").map(Model.parseHex);
    ok(blue.every(c => c.b > c.g && c.g > c.r), "a blue source stays blue");

    // And the ramp is about as long as a preset's, so it bands no worse.
    const preset = Model.gradientByKey("dusk").stops;
    const near = spread(preset[0], preset[1]);
    for (const src of ["#1e1e24", "#203141", "#eceef0", "#8a6d3b"]) {
        const g = Model.autoGradient(src);
        ok(Math.abs(spread(g[0], g[1]) - near) < 45,
           src + " spreads like a preset (" + spread(g[0], g[1]) + " vs " + near + ")");
    }

    eq(Model.autoGradient("not a color").length, 0, "garbage yields nothing");
});

test("a multipoint preset places its colors around the frame", () => {
    const mesh = Model.GRADIENTS.filter(Model.gradientIsMesh);
    ok(mesh.length >= 10, "there are multipoint presets");
    ok(mesh.every(g => g.base && !g.stops), "each has a base and no ramp");
    ok(mesh.every(g => Model.meshPoints(g).length >= 3), "and at least three points");

    // A ramp is not a mesh and a mesh is not a ramp; nothing carries both.
    ok(!Model.gradientIsMesh(Model.gradientByKey("dusk")), "dusk is a ramp");
    ok(Model.gradientIsMesh(Model.gradientByKey("bloom")), "bloom is a mesh");
    eq(Model.gradientStopCount("bloom"), 0, "a mesh has no stops to count");
    eq(Model.meshPoints(Model.gradientByKey("dusk")).length, 0, "and a ramp has no points");

    const p = Model.meshPoints(Model.gradientByKey("bloom"))[0];
    eq(p.x, 0.18); eq(p.y, 0.2); eq(p.color, "#6d4bd6");
    ok(p.r > 0, "with a radius to fade over");

    // Points are kept near the frame and given a usable radius, so a bad
    // preset cannot push a fill somewhere it will never be seen.
    const odd = Model.meshPoints({ points: [
        { x: 9, y: -9, r: 0, color: "#ffffff" },
        { x: 0.5, y: 0.5, color: "#000000" },
        { x: 0.5, y: 0.5 }
    ] });
    eq(odd.length, 2, "a point without a color is dropped");
    eq(odd[0].x, 1.5, "x clamped");
    eq(odd[0].y, -0.5, "y clamped");
    ok(odd[0].r > 0, "radius floored");
    ok(odd[1].r > 0, "a missing radius still gets one");
});

test("themes resolve, and anything unlisted is an installed Omarchy theme", () => {
    eq(Code.themeByKey("dracula").bat, "Dracula");
    eq(Code.themeByKey("").key, "omarchy", "no key falls back");
    eq(Code.languageLabel("rs"), "Rust");

    // The system themes arrive at runtime from bin/snap-themes, keyed by
    // their directory name, so an unknown key is one of those rather than
    // an error: it renders as bat's ansi output through that theme's palette.
    const t = Code.themeByKey("tokyo-night");
    eq(t.bat, "ansi", "rendered through the ansi mapping");
    eq(t.system, true, "flagged so the overlay fetches its palette");
    eq(t.bg, "", "colors come from the palette, not the table");
    eq(t.label, "Tokyo Night", "directory name becomes a readable label");
    eq(Code.themeByKey("catppuccin-latte").label, "Catppuccin Latte");
    eq(Code.themeByKey("nord").system, true, "bat's Nord no longer shadows Omarchy's");
});

console.log(passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
