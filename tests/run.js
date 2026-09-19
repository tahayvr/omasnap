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

test("window chrome is inside the card and the frame", () => {
    for (const frame of ["dots", "titlebar"]) {
        const g = Model.frameGeometry(Object.assign({}, base, { frame }));
        ok(g.chromeH >= 22 && g.chromeH <= 44, frame + " chrome clamped");
        eq(g.cardH, 500 + g.chromeH, frame + " card grows");
        eq(g.frameH, 700 + g.chromeH, frame + " frame grows");
    }
    eq(Model.frameGeometry(Object.assign({}, base, { frame: "none" })).chromeH, 0);
});

test("chrome scales with the shot but stays legible", () => {
    eq(Model.chromeHeight({ shotHeight: 100, frame: "dots" }), 22, "small shot");
    eq(Model.chromeHeight({ shotHeight: 4000, frame: "dots" }), 44, "huge shot");
    eq(Model.chromeHeight({ shotHeight: 1000, frame: "dots" }), 42, "proportional");
});

test("geometry survives an empty document", () => {
    const g = Model.frameGeometry({ shotWidth: 0, shotHeight: 0, padding: 5, ratio: "auto", balance: true, frame: "none" });
    ok(g.frameW >= 1 && g.frameH >= 1);
});

test("gradients and ratios resolve by key with a safe default", () => {
    eq(Model.gradientByKey("moss").a, "#1f3d2b");
    eq(Model.gradientByKey("nope").key, Model.GRADIENTS[0].key);
    ok(Model.RATIOS.some(r => r.key === "auto" && r.r === 0));
});

test("annotations carry every role the delegates read", () => {
    const a = Model.newAnnotation("box", 3, 4);
    for (const k of ["uid", "kind", "x", "y", "w", "h", "color", "width", "text", "index", "strength"])
        ok(k in a, "missing role " + k);
    ok(a.uid.length >= 6 && a.uid !== Model.newAnnotation("box", 0, 0).uid, "unique ids");
});

test("grab size undoes the device pixel ratio", () => {
    eq(Model.grabSize(480, 280, 1.6), { w: 300, h: 175 });
    eq(Model.grabSize(3840, 2160, 2), { w: 1920, h: 1080 });
    eq(Model.grabSize(1000, 500, 1), { w: 1000, h: 500 });
    eq(Model.grabSize(1000, 500, 0), { w: 1000, h: 500 }, "bad dpr falls back to 1");
    eq(Model.grabSize(1, 1, 3), { w: 1, h: 1 }, "never zero");
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

test("low-confidence words are ignored", () => {
    eq(Redact.findSensitive(tsv("mail a@b.io", { conf: 20 }), ALL).boxes, []);
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

console.log(passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
