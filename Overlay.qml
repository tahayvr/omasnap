import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "ui"
import "ui/controls"
import "lib/Redact.js" as Redact
import "lib/Model.js" as Model
import "lib/Code.js" as Code

Item {
    id: root

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null

    property bool opened: false
    property bool capturing: false
    property bool picking: false        // the system file dialog is up
    property bool eyedropping: false    // hyprpicker is up

    readonly property string pluginId: manifest && manifest.id ? manifest.id : "tahayvr.postcard"
    readonly property string pluginDir: decodeURIComponent(
        Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""))

    property string shotDir: Quickshell.env("HOME") + "/Pictures"

    readonly property string scratchDir: {
        var d = Quickshell.env("XDG_RUNTIME_DIR");
        return d && d.length ? d : "/tmp";
    }

    Doc { id: doc }

    Component.onCompleted: {
        dirProc.running = true;
        themeProc.running = true;
        wallpaperProc.running = true;
        themeListProc.running = true;
    }

    // The desktop palette feeds the "Omarchy" code theme; refresh it when the
    // shell's colors change.
    property string themeLines: ""
    Connections {
        target: Color
        function onBackgroundChanged() { themeProc.running = true; wallpaperProc.running = true; }
    }
    Process {
        id: themeProc
        command: ["bash", root.pluginDir + "bin/postcard-theme"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.themeLines = text;
                if (doc.kind === "code") root.applyCodeTheme();
            }
        }
    }

    // Every Omarchy theme installed here, offered as a code card theme.
    property var systemThemes: []
    Process {
        id: themeListProc
        command: ["bash", root.pluginDir + "bin/postcard-themes"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [], lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t");
                    if (parts.length === 2 && parts[0].length) rows.push({ key: parts[0], label: parts[1] });
                }
                root.systemThemes = rows;
            }
        }
    }

    // A card can wear a theme the desktop is not wearing, so that theme's
    // palette is read separately from the one driving the editor's chrome.
    property string codeThemeLines: ""
    Process {
        id: codeThemeProc
        property string theme: ""
        command: ["bash", root.pluginDir + "bin/postcard-theme", theme]
        stdout: StdioCollector {
            onStreamFinished: {
                root.codeThemeLines = text;
                root.applyCodeTheme();
                root.highlight();
            }
        }
    }

    // The desktop wallpaper, for the "desktop" background mode.
    Process {
        id: wallpaperProc
        command: ["bash", root.pluginDir + "bin/postcard-wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: doc.desktopBg = text.trim()
        }
    }

    function open(payloadJson) {
        if (capturing || captureProc.running) return "busy";
        var payload = {};
        try { payload = payloadJson ? JSON.parse(payloadJson) : {}; } catch (e) { payload = {}; }
        if (!payload || typeof payload !== "object") payload = {};

        opened = true;

        if (payload.path) {
            loadShot(String(payload.path));
        } else if (payload.text) {
            loadCode(String(payload.text));
        } else if (payload.code) {
            code();
        } else if (payload.capture) {
            var result = capture(String(payload.capture), payload.delay);
            if (result !== "ok") {
                // Otherwise the last picture comes up with no word of why
                // the capture never happened.
                if (!doc.hasContent) { dismiss(); return result; }
                editor.statusText = result === "bad delay"
                        ? "Delay must be 0 to 60 whole seconds" : "Busy, capture not started";
            }
        } else {
            // A plain open always starts clean: the empty state offers
            // region, code and file, and nothing from last time lingers.
            editor.statusText = "";
            doc.clearContent();
        }
        focusEditor();
    }

    // Shell calls this on hide; dismiss() calls it too, so it must be idempotent.
    function close() {
        opened = false;
        hideTimer.stop();
        countdown.stop();
        CaptureDelay.remaining = 0;
        eyedropTimer.stop();
        if (!eyedropProc.running) eyedropping = false;
        if (!captureProc.running) capturing = false;
        doc.selectedId = "";
    }

    function dismiss() {
        close();
        if (shell && typeof shell.hide === "function") shell.hide(pluginId);
    }

    // Public: edit, add, capture, save, saveAs, copy, crop, redact, copyText,
    // preset, help (see README, Scripting, and Model.helpText).
    function edit(path) {
        if (!path) return "no path";
        if (shell && typeof shell.summon === "function"
                && shell.summon(pluginId, JSON.stringify({ path: String(path) })))
            return "ok";
        open(JSON.stringify({ path: String(path) }));
        return "ok";
    }

    // help [topic]: usage, from the same lists the calls use.
    function help(topic) {
        return Model.helpText(topic);
    }

    // set <json>: change document settings, e.g. {"padding": 8, "codeTheme": "nord"}.
    // The keys, and what each takes, are Model.SETTABLE.
    readonly property var settable: Object.keys(Model.SETTABLE)
    function set(json) {
        var o;
        try { o = JSON.parse(json); } catch (e) { return "bad json"; }
        var applied = 0;
        for (var k in o) if (settable.indexOf(k) !== -1) { doc[k] = o[k]; applied++; }
        return applied ? "ok" : "nothing to set";
    }

    // annotate <json>: add annotations in screenshot pixels: one object
    // {kind, x, y, w, h, color, width, text, size, font, index, strength, zoom}, or several as
    // {"items": [...]} (the IPC CLI splits a bare top-level array on commas).
    function annotate(json) {
        var list;
        try { list = JSON.parse(json); } catch (e) { return "bad json"; }
        if (list && Array.isArray(list.items)) list = list.items;
        if (!Array.isArray(list)) list = [list];
        var added = 0;
        for (var i = 0; i < list.length; i++) {
            var o = list[i];
            if (!o || !o.kind) continue;
            var a = Model.newAnnotation(String(o.kind), Number(o.x) || 0, Number(o.y) || 0);
            a.w = Number(o.w) || 0;
            a.h = Number(o.h) || 0;
            a.color = o.color ? String(o.color) : String(doc.inkColor);
            a.width = Number(o.width) || doc.inkWidth;
            a.style = o.style ? String(o.style)
                    : (a.kind === "arrow" ? String(doc.arrowStyle) : "");
            a.text = o.text ? String(o.text) : "";
            // A label sized by width, as before it had a size, keeps that size.
            if (a.kind === "text") a.font = o.font ? String(o.font) : String(doc.textFont);
            if (a.kind === "text")
                a.fontSize = Number(o.size) || (Number(o.width) ? Model.textSize(a)
                           : doc.textSize || Model.defaultTextSize(doc.shotWidth, doc.shotHeight));
            a.strength = Number(o.strength) || Math.max(6, Math.round(doc.geo.shotW / 90));
            if (a.kind === "step") {
                doc.stepCounter += 1;
                a.index = Number(o.index) || doc.stepCounter;
                if (!a.w) {
                    var size = Math.max(22, Math.round(a.width * 9));
                    a.x -= size / 2; a.y -= size / 2; a.w = size; a.h = size;
                }
            }
            // As when drawn: the box is the area to magnify, and the lens is
            // set beside it.
            if (a.kind === "magnify") {
                var m = Model.magnifyFromDrag(a.x, a.y, a.x + a.w, a.y + a.h, Number(o.zoom));
                var lens = Model.placeMagnifier(m.sx, m.sy, m.w / 2 / Model.magnifyZoom(Number(o.zoom)),
                                                Number(o.zoom), doc.shotWidth, doc.shotHeight);
                if (m.w < 2 * Model.MIN_MAGNIFY) continue;
                a.zoom = Model.magnifyZoom(Number(o.zoom));
                a.sx = m.sx; a.sy = m.sy;
                a.x = lens.x; a.y = lens.y; a.w = lens.w; a.h = lens.h;
            }
            doc.annotations.append(a);
            added++;
        }
        doc.selectedId = "";
        doc.annotationsEdited();
        return added ? "ok" : "nothing added";
    }

    // info: the document as JSON.
    function info() {
        return JSON.stringify({
            // busy covers everything a script has to wait out before the
            // next call, not only what the editor shows as working.
            kind: doc.kind, opened: opened, capturing: capturing, picking: picking,
            busy: editor.busy || sheetProc.running || sizeProc.running || relayout.running
                  || textProc.running || ocrProc.running,
            hasContent: doc.hasContent,
            // Rendering is `busy`; encoding and writing the file comes after.
            delivering: deliver.running || dragFile.running, lastSaved: root.lastSaved,
            shotPath: doc.shotPath, shotWidth: doc.shotWidth, shotHeight: doc.shotHeight,
            outWidth: doc.outWidth, outHeight: doc.outHeight, annotations: doc.annotations.count,
            preset: doc.activePresetEntry.name, presetModified: doc.presetModified,
            bgMode: doc.bgMode, ratio: doc.ratio, padding: doc.padding, inset: doc.inset,
            frame: doc.frame, shotEdge: doc.shotEdge,
            shots: doc.slots.map(function (s) { return { name: s.name, crop: s.crop }; }),
            layout: doc.layoutDir, matchSizes: doc.matchSizes, slotGap: doc.slotGap,
            cropped: doc.cropped, cropRect: [doc.cropRect.x, doc.cropRect.y,
                                             doc.cropRect.width, doc.cropRect.height],
            codeLang: doc.codeLang, codeDetected: doc.codeDetected, codeTheme: doc.codeTheme,
            codeFont: doc.codeFont, codeNumbers: doc.codeNumbers, codeBg: String(doc.codeBg),
            codeFg: String(doc.codeFg), codeHtmlLength: doc.codeHtml.length
        });
    }

    // pick: open the system file dialog (the overlay hides so it is reachable).
    function pick() {
        return pickShot(false);
    }

    function pickShot(append) {
        if (picker.running) return "busy";
        picker.append = !!append && doc.hasContent && doc.kind === "shot";
        opened = true;
        picking = true;
        picker.running = true;
        return "ok";
    }

    // code <text>: render the text; with no argument, the selected text.
    function code(text) {
        if (text && String(text).length) { loadCode(String(text)); opened = true; return "ok"; }
        if (textProc.running) return "busy";
        opened = true;
        textProc.running = true;
        return "ok";
    }

    Process {
        id: textProc
        command: ["bash", root.pluginDir + "bin/postcard-text", String(Model.CODE_MAX)]
        stdout: StdioCollector {
            onStreamFinished: {
                // The first line says whether the selection was cut short.
                var nl = text.indexOf("\n");
                var body = nl >= 0 ? text.slice(nl + 1) : "";
                if (body.length) {
                    root.loadCode(body, text.slice(0, nl) === "cut");
                } else if (!doc.hasContent) {
                    root.dismiss();
                } else {
                    editor.statusText = "Nothing is selected";
                }
                root.focusEditor();
            }
        }
    }

    // cut: the selection was already trimmed on the way in.
    function loadCode(text, cut) {
        var clip = Model.clipCode(text, Model.CODE_MAX);
        text = clip.text.replace(/\r/g, "").replace(/\n+$/, "");
        if (!text.length) return;
        if (clip.cut || cut)
            Qt.callLater(function () {
                editor.statusText = "Only the first " + Model.plural(text.split("\n").length, "line") + " fit on a card";
            });
        doc.clearAnnotations();
        doc.resetHistory();
        // A code card is its own picture; shots left from before would still
        // size its inset and title bar.
        doc.slots = [];
        doc.sheet = null;
        // There is nothing to cut down on a card drawn from its own text.
        if (doc.tool === "crop") doc.tool = "select";
        doc.kind = "code";
        doc.shotPath = "";
        // The card's size is bound to CodeBlock in code mode; writing it here
        // would break that binding and leave the card empty.
        doc.autoPalette = [];
        doc.shotPalette = [];
        doc.shotEdge = "";
        doc.codeText = text;
        doc.codeDetected = Code.guessLanguage(text);
        doc.frameTitle = "snippet." + doc.codeEffectiveLang;
        applyCodeTheme();
        highlight();
        editor.statusText = Code.lineCount(text) + " lines \u00b7 " + Code.languageLabel(doc.codeEffectiveLang);
    }

    function codePalette() {
        var t = Code.themeByKey(doc.codeTheme);
        if (t.key === "omarchy") return Code.paletteFromTheme(root.themeLines, String(Color.foreground));
        if (t.system) return Code.paletteFromTheme(root.codeThemeLines, "");
        return Code.defaultPalette(t.fg);
    }

    function applyCodeTheme() {
        var t = Code.themeByKey(doc.codeTheme);
        var p = codePalette();
        doc.codeBg = t.bg || p.bg;
        doc.codeFg = t.fg || p.fg;
    }

    function highlight() {
        if (doc.kind !== "code" || !doc.codeText.length) return;
        if (highlightProc.running) { highlightProc.pending = true; return; }
        highlightProc.pending = false;
        highlightProc.input = doc.codeText;
        highlightProc.running = true;
    }

    Process {
        id: highlightProc
        property string input: ""
        property bool pending: false
        command: ["bash", root.pluginDir + "bin/postcard-highlight", doc.codeEffectiveLang,
                  Code.themeByKey(doc.codeTheme).bat, doc.codeNumbers ? "1" : "0",
                  String(Code.WRAP_COLUMNS)]
        stdinEnabled: true
        onRunningChanged: {
            if (running) { write(input); stdinEnabled = false; }
            else stdinEnabled = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                doc.codeHtml = Code.ansiToHtml(text, root.codePalette(),
                    doc.codeNumbers ? Code.gutterColor(String(doc.codeFg), String(doc.codeBg)) : "");
                if (highlightProc.pending) root.highlight();
            }
        }
    }

    Connections {
        target: doc
        function onCodeLangChanged() { doc.frameTitle = "snippet." + doc.codeEffectiveLang; root.highlight(); }
        function onCodeThemeChanged() {
            var t = Code.themeByKey(doc.codeTheme);
            if (t.system) {
                // applyCodeTheme and highlight run once its palette arrives.
                root.codeThemeLines = "";
                codeThemeProc.theme = t.key;
                codeThemeProc.running = true;
                return;
            }
            root.applyCodeTheme();
            root.highlight();
        }
        function onCodeNumbersChanged() { root.highlight(); }
    }

    function focusEditor() {
        Qt.callLater(function () { if (window.visible) scope.forceActiveFocus(); });
    }

    // A new picture, alone on the card. With recut the shots stay and only
    // the picture on show changes: a new sheet for them, after a crop or a
    // change of layout, keeping the marks (applySlots has moved them).
    function loadShot(path, recut) {
        if (!path) return;
        if (!recut) {
            doc.clearAnnotations();
            doc.resetHistory();
            doc.shotName = path.split("/").pop();
            doc.frameTitle = doc.shotName;
            // Its size comes from the probe, which then lays it out.
            doc.slots = [Model.newSlot(path, 0, 0)];
            doc.sheet = null;
            doc.autoPalette = [];
            doc.shotPalette = [];
            doc.shotEdge = "";
            // The first shot sets the colors: the backdrop, the title bar,
            // and the inset band of any shot without an edge of its own.
            paletteProc.path = path;
            paletteProc.running = true;
            edgeProc.path = path;
            edgeProc.running = true;
        }
        doc.cropRect = Qt.rect(0, 0, 0, 0);
        doc.kind = "shot";
        doc.codeText = "";
        doc.codeHtml = "";
        doc.shotWidth = 0;
        doc.shotHeight = 0;
        doc.shotPath = path;
        doc.shotRevision += 1;
        probe.source = "";
        probe.source = doc.shotUrl;
    }

    // ---- several shots ----------------------------------------------------

    function layoutOptions() {
        return { dir: doc.layoutDir, gap: doc.slotGap, match: doc.matchSizes,
                 align: doc.slotAlign, inset: doc.inset, frame: doc.frame };
    }

    // Every change to the shots comes through here: lay them out, compose
    // the sheet if one is needed, and only once it exists move the marks
    // and swap the picture, so nothing is ever drawn on a layout the
    // picture does not have yet. A request made while a sheet is being
    // composed waits, and the latest one wins.
    property var slotsWanted: null
    function applySlots(slots, note) {
        if (slots.length === 0) return "no shot";
        if (sheetProc.running) { root.slotsWanted = { slots: slots, note: note }; return "ok"; }
        var L = Model.sheetLayout(slots, root.layoutOptions());
        if (!Model.needsSheet(slots)) {
            root.commitSlots(slots, L, slots[0].source, note);
            return "ok";
        }
        var args = Model.sheetArgs(slots, L);
        sheetProc.pending = { slots: slots, layout: L, note: note,
                              dest: root.scratchDir + "/" + Model.sheetName(args) };
        sheetProc.command = ["bash", root.pluginDir + "bin/postcard-sheet", sheetProc.pending.dest].concat(args);
        sheetProc.running = true;
        return "ok";
    }

    function commitSlots(slots, L, path, note) {
        // An edge color can arrive while the sheet is still being composed,
        // before its shot is on the document at all.
        slots = slots.map(function (s) {
            var c = root.slotEdges[s.id];
            return c && s.edge !== c ? Object.assign({}, s, { edge: c }) : s;
        });
        var gone = 0;
        if (doc.sheet) {
            var r = Model.remapAnnotations(JSON.parse(doc.snapshot()), doc.sheet, doc.slots, L, slots);
            doc.replaceAnnotations(r.marks);
            gone = r.dropped;
        }
        doc.slots = slots;
        doc.sheet = L;
        loadShot(path, true);
        // Undo is about the marks; stepping back past a change of layout
        // would put them where the shots no longer are.
        doc.resetHistory();
        if (note) editor.statusText = note + (gone > 0 ? "  \u00b7  " + Model.plural(gone, "annotation") + " dropped" : "");
    }

    Process {
        id: sheetProc
        property var pending: null
        stdout: StdioCollector {
            onStreamFinished: {
                var p = sheetProc.pending;
                if (text.trim() !== "ok") {
                    editor.statusText = text.trim().length ? text.trim() : "Could not lay the shots out";
                } else {
                    root.commitSlots(p.slots, p.layout, p.dest, p.note);
                }
                var next = root.slotsWanted;
                root.slotsWanted = null;
                if (next) root.applySlots(next.slots, next.note);
            }
        }
    }

    // A layout setting, or a style change that moves the shots, lays them
    // out again. Held back a moment so a slider drag composes once.
    Timer {
        id: relayout
        interval: 250
        onTriggered: if (doc.shotCount > 1) root.applySlots(doc.slots, "")
    }
    Connections {
        target: doc
        function onLayoutDirChanged() { relayout.restart(); }
        function onSlotGapChanged() { relayout.restart(); }
        function onMatchSizesChanged() { relayout.restart(); }
        function onSlotAlignChanged() { relayout.restart(); }
        function onInsetChanged() { relayout.restart(); }
        function onFrameChanged() { relayout.restart(); }
    }

    // add <mode|path>: another shot beside the ones on the card, captured
    // (region, windows, fullscreen, smart, or {"mode":..,"delay":..}) or
    // from a file. With nothing open it is the first shot.
    function add(what) {
        var w = String(what || "").trim();
        if (w === "" || w === "file") return pickShot(true);
        if (w.indexOf("{") === 0 || Model.CAPTURE_MODES.indexOf(w) !== -1) return capture(w, undefined, true);
        addShot(w);
        return "ok";
    }

    function addShot(path) {
        if (!doc.hasContent || doc.kind !== "shot" || !doc.sheet) {
            if (!opened) edit(path); else loadShot(path);
            return;
        }
        sizeProc.path = path;
        sizeProc.running = true;
    }

    Process {
        id: sizeProc
        property string path: ""
        command: ["magick", "identify", "-format", "%w %h", sizeProc.path + "[0]"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = /^(\d+) (\d+)/.exec(text.trim());
                if (!m) { editor.statusText = "Could not open that image"; return; }
                var slot = Model.newSlot(sizeProc.path, parseInt(m[1]), parseInt(m[2]));
                root.applySlots(doc.slots.concat([slot]), "Added " + slot.name);
                slotEdgeProc.slotId = slot.id;
                slotEdgeProc.path = sizeProc.path;
                slotEdgeProc.running = true;
            }
        }
    }

    // A shot's own edge color, for its card's inset band.
    Process {
        id: slotEdgeProc
        property string slotId: ""
        property string path: ""
        command: ["bash", root.pluginDir + "bin/postcard-edge", path]
        stdout: StdioCollector {
            onStreamFinished: root.setSlotEdge(slotEdgeProc.slotId, text.trim())
        }
    }

    // Each shot's edge color by its id, kept apart from the slots so one that
    // arrives mid-layout is not lost (commitSlots puts it on).
    property var slotEdges: ({})
    function setSlotEdge(id, c) {
        if (!/^#[0-9a-fA-F]{6}$/.test(c)) return;
        var e = Object.assign({}, root.slotEdges);
        e[id] = c;
        root.slotEdges = e;
        doc.slots = doc.slots.map(function (s) {
            return s.id === id ? Object.assign({}, s, { edge: c }) : s;
        });
    }

    function removeSlot(id) {
        if (doc.shotCount < 2) return "last shot";
        var gone = doc.slots.filter(function (s) { return s.id === id; });
        if (!gone.length) return "no such shot";
        return applySlots(doc.slots.filter(function (s) { return s.id !== id; }), "Removed " + gone[0].name);
    }

    function moveSlot(id, by) {
        var i = Model.slotById(doc.slots, id), j = i + by;
        if (i < 0 || j < 0 || j >= doc.shotCount) return "no move";
        var s = doc.slots.slice();
        s.splice(j, 0, s.splice(i, 1)[0]);
        return applySlots(s, "");
    }

    function uncropSlot(id) {
        return applySlots(doc.slots.map(function (s) {
            return s.id === id ? Object.assign({}, s, { crop: null }) : s;
        }), "Crop removed");
    }

    Image {
        id: probe
        visible: false
        asynchronous: true
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) {
                doc.shotWidth = implicitWidth;
                doc.shotHeight = implicitHeight;
                // A picture just opened: now its size is known, it has a layout.
                if (doc.sheet === null && doc.shotCount === 1) {
                    var first = Object.assign({}, doc.slots[0], { w: implicitWidth, h: implicitHeight });
                    doc.slots = [first];
                    doc.sheet = Model.sheetLayout(doc.slots, root.layoutOptions());
                }
                editor.statusText = implicitWidth + "×" + implicitHeight + " loaded";
            } else if (status === Image.Error) {
                editor.statusText = "Could not open that image";
            }
        }
    }

    Process {
        id: dirProc
        command: ["bash", root.pluginDir + "bin/postcard-dir"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = text.trim();
                if (d.length && d.indexOf("/") === 0) root.shotDir = d;
            }
        }
    }

    // With append the shot goes beside the ones already on the card.
    function capture(mode, delay, append) {
        if (capturing || captureProc.running || picking || eyedropping || editor.busy) return "busy";
        captureProc.append = !!append && doc.hasContent && doc.kind === "shot";
        var request = Model.captureRequest(mode, delay);
        if (request.error) return request.error;
        opened = true;
        capturing = true;
        captureProc.mode = request.mode;
        CaptureDelay.remaining = request.seconds;
        if (request.seconds > 0) countdown.restart();
        else hideTimer.restart();
        return "ok";
    }

    // The overlay steps aside like it does for a capture, so the pick is from
    // what is behind it rather than from the editor itself.
    property var eyedropDone: null
    function eyedrop(done) {
        if (eyedropping || eyedropProc.running) return "busy";
        eyedropDone = done;
        eyedropping = true;
        eyedropTimer.restart();
        return "ok";
    }

    Timer {
        id: eyedropTimer
        interval: 140      // let the layer surface actually leave the screen
        onTriggered: eyedropProc.running = true
    }

    Process {
        id: eyedropProc
        command: ["bash", root.pluginDir + "bin/postcard-eyedrop"]
        stdout: StdioCollector {
            onStreamFinished: {
                var hex = Model.normaliseHex(text.trim());
                var done = root.eyedropDone;
                root.eyedropDone = null;
                root.eyedropping = false;
                if (hex && done) done(hex);
                root.focusEditor();
            }
        }
    }

    // The user's own colors and gradients outlive the shell, unlike the rest
    // of the styling: written here and read back on load. Never under the
    // plugin directory, where any write reloads it.
    readonly property string colorsFile: {
        var d = Quickshell.env("XDG_CONFIG_HOME");
        return (d && d.length ? d : Quickshell.env("HOME") + "/.config") + "/postcard/colors.json";
    }
    // Nothing is written until the file has been read, or the defaults would
    // overwrite what was saved last time.
    property bool colorsReady: false

    // Each file is brought up to this build's version as it is read, and an
    // older one is written back at once (Model.CONFIG_FILES). One from a newer
    // Postcard is read and left alone: tooNew holds its name.
    property var tooNew: ({})

    // The parsed file, migrated; null when there is nothing usable. Returns
    // through `done` whether the file on disk should be rewritten.
    function openConfig(kind, json, done) {
        var o;
        try { o = JSON.parse(json); } catch (e) { return null; }
        if (!o || typeof o !== "object") return null;
        var m = Model.migrateConfig(kind, o);
        if (m.tooNew) {
            var t = Object.assign({}, root.tooNew);
            t[kind] = true;
            root.tooNew = t;
            console.warn("postcard: " + kind + ".json is version " + m.from
                         + ", newer than this Postcard; not writing to it");
        }
        done(!m.tooNew && m.from < Model.CONFIG_FILES[kind].version);
        return m.data;
    }

    function writeConfig(kind, view, values) {
        if (root.tooNew[kind]) return;
        view.setText(JSON.stringify(Model.configFile(kind, values), null, 2) + "\n");
    }

    function readColors(json) {
        var o = root.openConfig("colors", json, function (stale) { if (stale) colorsSave.restart(); });
        if (!o) return;
        if (Array.isArray(o.customColors)) {
            var kept = [];
            for (var i = o.customColors.length - 1; i >= 0; i--)
                kept = Model.rememberColor(kept, o.customColors[i]);
            doc.customColors = kept;
        }
        if (Array.isArray(o.inkColors)) {
            var inks = [];
            for (var k = o.inkColors.length - 1; k >= 0; k--)
                inks = Model.rememberColor(inks, o.inkColors[k], false, Model.INK_COLORS_KEPT);
            doc.inkColors = inks;
        }
        if (Array.isArray(o.gradients)) {
            var saved = [];
            for (var j = o.gradients.length - 1; j >= 0; j--)
                saved = Model.saveGradient(saved, o.gradients[j]);
            doc.userGradients = saved;
        }
    }

    FileView {
        id: colorsView
        path: root.colorsFile
        printErrors: false
        onLoaded: {
            root.readColors(colorsView.text());
            root.colorsReady = true;
        }
        onLoadFailed: root.colorsReady = true
    }

    Timer {
        id: colorsSave
        interval: 500
        onTriggered: root.writeConfig("colors", colorsView, {
            customColors: doc.customColors,
            inkColors: doc.inkColors,
            gradients: doc.userGradients
        })
    }

    Connections {
        target: doc
        function onCustomColorsChanged() { if (root.colorsReady) colorsSave.restart(); }
        function onInkColorsChanged() { if (root.colorsReady) colorsSave.restart(); }
        function onUserGradientsChanged() { if (root.colorsReady) colorsSave.restart(); }
    }

    // Presets have a file of their own beside the colors, read and written
    // the same way. The one in use is saved with them and put back on load,
    // so a preset picked once is the look every capture starts from.
    readonly property string presetsFile: root.colorsFile.replace(/colors\.json$/, "presets.json")
    property bool presetsReady: false

    function readPresets(json) {
        var o = root.openConfig("presets", json, function (stale) { if (stale) presetsSave.restart(); });
        if (!o || !Array.isArray(o.presets)) return;
        var list = [];
        for (var i = 0; i < o.presets.length; i++) list = Model.savePreset(list, o.presets[i]);
        doc.presets = list;
        if (o.active && o.active !== Model.DEFAULT_PRESET) doc.applyPreset(String(o.active));
    }

    FileView {
        id: presetsView
        path: root.presetsFile
        printErrors: false
        onLoaded: {
            root.readPresets(presetsView.text());
            root.presetsReady = true;
        }
        onLoadFailed: root.presetsReady = true
    }

    Timer {
        id: presetsSave
        interval: 500
        onTriggered: root.writeConfig("presets", presetsView, {
            active: doc.activePreset,
            presets: doc.presets
        })
    }

    Connections {
        target: doc
        function onPresetsChanged() { if (root.presetsReady) presetsSave.restart(); }
        function onActivePresetChanged() { if (root.presetsReady) presetsSave.restart(); }
    }

    // Preferences have a file of their own too, read and written like the
    // presets. Model.DEFAULT_SETTINGS names every key.
    readonly property string settingsFile: root.colorsFile.replace(/colors\.json$/, "settings.json")
    property bool settingsReady: false

    function readSettings(json) {
        var o = root.openConfig("settings", json, function (stale) { if (stale) settingsSave.restart(); });
        var s = Model.cleanSettings(o);
        for (var k in s) doc[k] = s[k];
    }

    FileView {
        id: settingsView
        path: root.settingsFile
        printErrors: false
        onLoaded: {
            root.readSettings(settingsView.text());
            root.settingsReady = true;
        }
        onLoadFailed: root.settingsReady = true
    }

    Timer {
        id: settingsSave
        interval: 500
        onTriggered: {
            var values = {};
            for (var k in Model.DEFAULT_SETTINGS) values[k] = doc[k];
            root.writeConfig("settings", settingsView, Model.cleanSettings(values));
        }
    }

    Connections {
        target: doc
        function onSaveCopiesChanged() { if (root.settingsReady) settingsSave.restart(); }
    }

    // preset <name>: put a saved preset on the card, by name or id, or
    // "default". The command line splits on spaces, so a name with one is
    // typed with a dash or an underscore instead (Model.presetKey).
    function preset(name) {
        return doc.applyPreset(String(name || "")) ? "ok" : "unknown preset";
    }

    function redact() {
        if (doc.kind === "code") { editor.statusText = "Use the Hide tool to pixelate code"; return "no shot"; }
        if (!doc.hasContent) return "no shot";
        if (ocrProc.running) return "busy";
        editor.busy = true;
        editor.statusText = "Reading the screenshot…";
        ocrProc.purpose = "redact";
        ocrProc.running = true;
        return "ok";
    }

    function copyText() {
        if (doc.kind === "code" && doc.codeText.length) {
            clipText.text = doc.codeText;
            clipText.running = true;
            editor.statusText = "Code copied to the clipboard";
            return "ok";
        }
        if (!doc.hasContent) return "no shot";
        if (ocrProc.running) return "busy";
        editor.busy = true;
        ocrProc.purpose = "text";
        ocrProc.running = true;
        return "ok";
    }

    // Ticks in whole seconds so the bar can show the count; the unmap pause
    // still follows the last tick, so the shot never has the count in it.
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            CaptureDelay.remaining -= 1;
            if (CaptureDelay.remaining > 0) return;
            stop();
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 140      // let the layer surface actually leave the screen
        onTriggered: captureProc.running = true
    }

    Process {
        id: captureProc
        property string mode: "region"
        property bool append: false
        // Adding a shot keeps the captures already on the card.
        command: ["bash", root.pluginDir + "bin/postcard-capture", mode].concat(
                     append ? doc.slots.map(function (s) { return s.source; }) : [])
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var path = lines[lines.length - 1].trim();
                root.capturing = false;
                if (path.length > 0 && path.indexOf("/") === 0) {
                    if (captureProc.append) root.addShot(path); else root.loadShot(path);
                } else if (!doc.hasContent) {
                    root.dismiss();    // cancelled with nothing to fall back to
                } else {
                    editor.statusText = "Capture cancelled";
                }
                root.focusEditor();
            }
        }
    }

    Process {
        id: paletteProc
        property string path: ""
        command: ["bash", root.pluginDir + "bin/postcard-palette", path]
        stdout: StdioCollector {
            onStreamFinished: {
                // Each line is "#backdrop #source".
                var backdrops = [], sources = [];
                var lines = text.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var m = /^(#[0-9a-fA-F]{6})\s+(#[0-9a-fA-F]{6})$/.exec(lines[i].trim());
                    if (!m) continue;
                    backdrops.push(m[1]);
                    sources.push(m[2]);
                }
                doc.autoPalette = backdrops.slice(0, 5);
                doc.shotPalette = sources.slice(0, 5);
            }
        }
    }

    Process {
        id: edgeProc
        property string path: ""
        command: ["bash", root.pluginDir + "bin/postcard-edge", path]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim();
                doc.shotEdge = /^#[0-9a-fA-F]{6}$/.test(c) ? c : "";
                if (doc.shotCount > 0) root.setSlotEdge(doc.slots[0].id, c);
            }
        }
    }

    Process {
        id: ocrProc
        property string purpose: "redact"
        command: ["bash", root.pluginDir + "bin/postcard-ocr", doc.shotPath, purpose]
        stdout: StdioCollector {
            onStreamFinished: {
                if (ocrProc.purpose === "text") {
                    clipText.text = text;
                    clipText.running = true;
                    editor.statusText = text.trim().length
                        ? "Text copied to the clipboard"
                        : "No text found in this screenshot";
                    return;
                }
                root.applyRedaction(text);
            }
        }
        onExited: function (code) {
            if (code !== 0) editor.statusText = "OCR failed";
            editor.busy = false;
        }
    }

    function applyRedaction(tsv) {
        var found = Redact.findSensitive(tsv, doc.redactClasses);
        for (var i = 0; i < found.boxes.length; i++) {
            var b = found.boxes[i];
            var a = Model.newAnnotation("redact", b.x, b.y);
            a.w = b.w;
            a.h = b.h;
            a.strength = Math.max(6, Math.round(b.h / 2.2));
            doc.annotations.append(a);
        }
        doc.annotationsEdited();
        editor.statusText = Redact.summarize(found.counts);
    }

    Process {
        id: clipText
        property string text: ""
        command: ["bash", root.pluginDir + "bin/postcard-deliver", "text"]
        stdinEnabled: true
        // Closing stdin ends the input; reopen it so the next run can write.
        onRunningChanged: {
            if (running) { write(text); stdinEnabled = false; }
            else stdinEnabled = true;
        }
    }

    // grabToImage never calls back while the screen is locked or once the
    // window unmaps mid-grab, and busy would then hold off every save, copy
    // and capture until the shell restarts. A real render takes seconds.
    property int exportGeneration: 0
    Timer {
        id: exportWatchdog
        interval: 20000
        onTriggered: {
            root.exportGeneration++;
            doc.exporting = false;
            editor.busy = false;
            editor.statusText = "Render timed out";
        }
    }

    function exportTo(path, andThen) {
        if (!doc.hasContent) return "no shot";
        if (editor.busy) return "busy";
        // grabToImage needs the item on a mapped window; while the overlay is
        // hidden it fails after answering ok, with a status nobody can see.
        if (!window.visible) return "closed";
        if (doc.outputTooLarge) {
            editor.statusText = "Too large to render — pick a smaller export scale";
            return "too large";
        }
        editor.busy = true;
        doc.exporting = true;
        var generation = ++root.exportGeneration;
        exportWatchdog.restart();

        Qt.callLater(function () {
            var target = editor.exportTarget;
            var size = Qt.size(target.width * doc.exportScale, target.height * doc.exportScale);
            var ok = target.grabToImage(function (result) {
                // Given up on already: writing now would surprise, and
                // clearing busy could cut across a newer export.
                if (generation !== root.exportGeneration) return;
                exportWatchdog.stop();
                var wrote = result.saveToFile(path);
                doc.exporting = false;
                editor.busy = false;
                if (!wrote) {
                    editor.statusText = "Could not write " + path;
                    return;
                }
                if (andThen) andThen(path);
            }, size);

            if (!ok) {
                exportWatchdog.stop();
                doc.exporting = false;
                editor.busy = false;
                editor.statusText = "Render failed — try a smaller export scale";
            }
        });
        return "ok";
    }

    // crop <json>: crop to {x,y,w,h} in the picture on show, or with no
    // argument to whatever is selected in the editor. With "select":true the
    // rectangle is only shown, to be taken or redrawn by hand.
    function crop(json) {
        if (doc.kind !== "shot" || !doc.hasContent) return "no shot";
        if (sheetProc.running) return "busy";
        if (json && String(json).length) {
            var o;
            try { o = JSON.parse(json); } catch (e) { return "bad json"; }
            // Qt.rect, not the plain object: assigning one straight to a rect
            // property keeps only x and y, since a rect spells its size
            // width/height.
            var r = Model.cropRect(Number(o.x) || 0, Number(o.y) || 0,
                                   Number(o.w) || 0, Number(o.h) || 0,
                                   doc.shotWidth, doc.shotHeight);
            doc.cropRect = Qt.rect(r.x, r.y, r.w, r.h);
            if (o.select) return doc.cropUsable ? "ok" : "too small";
        }
        if (!doc.cropUsable) return "no selection";
        if (!doc.sheet || sheetProc.running) return "busy";

        // The shot the selection is on is cropped, and only that one.
        var sel = { x: doc.cropRect.x, y: doc.cropRect.y, w: doc.cropRect.width, h: doc.cropRect.height };
        var i = Model.slotIndexAt(doc.sheet, sel.x + sel.w / 2, sel.y + sel.h / 2);
        var id = doc.sheet.items[i].id;
        var k = Model.slotById(doc.slots, id);
        var c = Model.cropForSlot(sel, doc.sheet.items[i], doc.slots[k]);
        if (!c) return "too small";
        var slots = doc.slots.slice();
        slots[k] = Object.assign({}, slots[k], { crop: c });
        doc.tool = "select";
        return applySlots(slots, "Cropped to " + c.w + "\u00d7" + c.h);
    }

    // uncrop: every shot back to its whole picture, marks and all.
    function uncrop() {
        if (!doc.cropped) return "not cropped";
        return applySlots(doc.slots.map(function (s) { return Object.assign({}, s, { crop: null }); }),
                          "Crop removed");
    }

    function outputName() {
        return "postcard-" + Model.stamp() + "." + Model.exportExtension(doc.format);
    }

    function outputPath() {
        return root.shotDir + "/" + outputName();
    }

    function save() {
        return exportTo(root.scratchDir + "/postcard-out.png", function (p) {
            deliver.args = ["save-new", p, outputPath(), doc.format, String(doc.quality),
                            String(doc.outWidth), String(doc.outHeight), doc.saveCopies ? "1" : "0"];
            deliver.running = true;
        });
    }

    // saveAs: render first and only then raise the dialog. The overlay has to
    // hide for the dialog to be reachable, and grabToImage cannot render an
    // unmapped window.
    function saveAs() {
        if (saver.running) return "busy";
        return exportTo(root.scratchDir + "/postcard-out.png", function (p) {
            saver.rendered = p;
            // A function call in a binding would never re-evaluate, and the
            // suggested name carries the time and the current format.
            saver.command = ["bash", root.pluginDir + "bin/postcard-pick", "save",
                             root.shotDir, root.outputName()];
            root.picking = true;
            saver.running = true;
        });
    }

    function copy() {
        return exportTo(root.scratchDir + "/postcard-copy.png", function (p) {
            deliver.args = ["copy", p, "", doc.format, String(doc.quality),
                            String(doc.outWidth), String(doc.outHeight)];
            deliver.running = true;
        });
    }

    // dragOut: render, then hand the file to the editor to drag, if the button
    // is still held by the time it is ready.
    function dragOut() {
        return exportTo(root.scratchDir + "/postcard-drag.png", function (p) {
            dragFile.args = ["file", p, root.scratchDir + "/postcard-drag/" + root.outputName(),
                             doc.format, String(doc.quality),
                             String(doc.outWidth), String(doc.outHeight)];
            dragFile.running = true;
        });
    }

    Process {
        id: dragFile
        property var args: []
        command: ["bash", root.pluginDir + "bin/postcard-deliver"].concat(args)
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path.indexOf("/") === 0) editor.startDragOut(path);
            }
        }
    }

    Process {
        id: deliver
        property var args: []
        command: ["bash", root.pluginDir + "bin/postcard-deliver"].concat(args)
        stdout: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length) editor.statusText = msg;
                // For a script to pick the file up from, through `info`.
                // The name comes back from the script, which may have had to
                // pick a free one.
                if (deliver.args[0].indexOf("save") === 0 && msg.indexOf("Saved ") === 0) {
                    var dest = String(deliver.args[2]);
                    root.lastSaved = dest.slice(0, dest.lastIndexOf("/") + 1) + msg.slice(6);
                }
            }
        }
    }

    // The last file a save wrote, for scripts.
    property string lastSaved: ""

    function editSelectedText(event) {
        if (doc.selectedIds.length !== 1) return false;
        var i = doc.indexOfId(doc.selectedId);
        if (i < 0) return false;
        var a = doc.annotations.get(i);
        if (a.kind !== "text") return false;
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false;

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            doc.selectedId = "";
            return true;
        }
        if (event.key === Qt.Key_Backspace) {
            doc.annotations.setProperty(i, "text", a.text.slice(0, -1));
            doc.annotationsEdited();
            return true;
        }
        // Delete arrives with DEL (127) as its text, which typed itself into
        // the label; it is left to remove the label like any other mark.
        if (event.key === Qt.Key_Delete) return false;
        if (event.text && event.text.length && event.text.charCodeAt(0) >= 32
                && event.text.charCodeAt(0) !== 127) {
            doc.annotations.setProperty(i, "text", a.text + event.text);
            doc.annotationsEdited();
            return true;
        }
        return false;
    }

    // Arrow keys move the selected marks a shot pixel at a time, ten with
    // Shift. Like a drag, a magnifier's lens moves and what it shows stays.
    function nudgeSelected(event) {
        if (doc.selectedIds.length === 0) return false;
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return false;
        var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
        var dx = 0, dy = 0;
        switch (event.key) {
        case Qt.Key_Left:  dx = -step; break;
        case Qt.Key_Right: dx = step;  break;
        case Qt.Key_Up:    dy = -step; break;
        case Qt.Key_Down:  dy = step;  break;
        default: return false;
        }
        doc.moveSelection(dx, dy, "");
        return true;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (doc.cropUsable) doc.cropRect = Qt.rect(0, 0, 0, 0);
            else if (editor.settingsOpen) editor.settingsOpen = false;
            else if (doc.selectedId !== "") doc.selectedId = "";
            else root.dismiss();
            return true;
        }

        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && doc.tool === "crop" && doc.cropUsable) {
            root.crop("");
            return true;
        }

        if (editSelectedText(event)) return true;

        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            return doc.removeSelection() > 0;
        }

        if (nudgeSelected(event)) return true;

        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            // With marks selected the clipboard keys are about them; with
            // none, Ctrl+C copies the picture as it always has.
            case Qt.Key_C:
                if (doc.selectedIds.length === 0) { root.copy(); return true; }
                var copied = doc.copySelection();
                editor.statusText = copied ? "Copied " + Model.plural(copied, "mark") : "Nothing to copy";
                return true;
            case Qt.Key_X:
                var cut = doc.copySelection();
                if (cut) { doc.removeSelection(); editor.statusText = "Cut " + Model.plural(cut, "mark"); }
                return true;
            case Qt.Key_V:
                if (doc.paste() === 0) editor.statusText = "No marks copied";
                return true;
            case Qt.Key_D: doc.duplicateSelection(); return true;
            case Qt.Key_S:
                if (event.modifiers & Qt.ShiftModifier) root.saveAs(); else root.save();
                return true;
            case Qt.Key_A: doc.selectAll(); return true;
            case Qt.Key_Z:
                if (event.modifiers & Qt.ShiftModifier) doc.redo(); else doc.undo();
                return true;
            case Qt.Key_Y: doc.redo(); return true;
            case Qt.Key_N: root.capture("region"); return true;
            case Qt.Key_K: root.code(); return true;
            }
            return false;
        }

        var map = {};
        map[Qt.Key_V] = "select";  map[Qt.Key_A] = "arrow";
        map[Qt.Key_R] = "box";     map[Qt.Key_O] = "ellipse";
        map[Qt.Key_T] = "text";    map[Qt.Key_S] = "step";
        map[Qt.Key_H] = "highlight"; map[Qt.Key_B] = "redact";
        map[Qt.Key_L] = "spotlight"; map[Qt.Key_M] = "magnify";
        if (doc.kind === "shot") map[Qt.Key_C] = "crop";
        if (map[event.key] !== undefined) {
            doc.tool = map[event.key];
            doc.selectedId = "";
            return true;
        }
        return false;
    }

    // The backdrop is a window of its own, under the card's. Dragging the
    // picture out needs the card's window to be no bigger than the card:
    // Hyprland picks a drop target without looking at a surface's input
    // region, so a full-screen overlay was the only place a drag could land,
    // and neither shrinking it nor masking it once the press had begun let
    // the drag reach anything else. The backdrop simply goes while a drag
    // is under way.
    PanelWindow {
        id: backdrop
        visible: window.visible && !editor.draggingOut
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "postcard-backdrop"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Color.menu && Color.menu.scrim ? Color.menu.scrim : Qt.rgba(0, 0, 0, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }
        }
    }

    PanelWindow {
        id: window
        visible: root.opened && !root.capturing && !root.picking && !root.eyedropping
        color: "transparent"

        // No anchors: the compositor centres a layer that has none.
        implicitWidth: Math.min(Style.space(1320), (screen ? screen.width : 0) - Style.gapsOut * 4)
        implicitHeight: Math.min(Style.space(860), (screen ? screen.height : 0) - Style.gapsOut * 4)
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "postcard"
        // On demand rather than exclusive: an exclusive layer keeps the
        // pointer from every other surface, the backdrop included, so a
        // click outside the card would not close it. The keyboard is let go
        // as a drag begins, or the drag never reaches another window (any
        // sooner and the press is lost with it), and taken back once it
        // ends, since whatever was dropped on has it by then.
        WlrLayershell.keyboardFocus: editor.dragActive ? WlrKeyboardFocus.None
                                   : reclaim.running ? WlrKeyboardFocus.Exclusive
                                   : WlrKeyboardFocus.OnDemand

        Timer {
            id: reclaim
            interval: 150
        }
        Connections {
            target: editor
            function onDragActiveChanged() { if (!editor.dragActive) reclaim.restart(); }
        }

        onVisibleChanged: if (visible) root.focusEditor()

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true

            Editor {
                id: editor
                anchors.fill: parent
                doc: doc
                systemThemes: root.systemThemes
                saveDir: root.shotDir
                radius: 0

                onEyedropRequested: function (done) { root.eyedrop(done); }
                onCaptureRequested: function (mode) { root.capture(mode, mode === "fullscreen" ? CaptureDelay.seconds : 0); }
                onCodeRequested: root.code()
                onCloseRequested: root.dismiss()
                onCopyRequested: root.copy()
                onDragOutRequested: root.dragOut()
                onLogoRequested: root.pickLogo()
                onAddShotRequested: function (how) { root.add(how); }
                onShotRequested: function (action, id) {
                    if (action === "left") root.moveSlot(id, -1);
                    else if (action === "right") root.moveSlot(id, 1);
                    else if (action === "uncrop") root.uncropSlot(id);
                    else if (action === "remove") root.removeSlot(id);
                }
                onSaveRequested: root.save()
                onSaveAsRequested: root.saveAs()
                onOpenRequested: root.pick()
                onAutoRedactRequested: root.redact()
                onCropRequested: root.crop("")
                onUncropRequested: root.uncrop()
                onCopyTextRequested: root.copyText()
            }

            Keys.onPressed: function (event) {
                if (root.handleKey(event)) event.accepted = true;
            }
        }
    }

    Process {
        id: saver
        property string rendered: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var dest = text.trim();
                root.picking = false;
                root.focusEditor();
                if (!dest.length || dest.indexOf("/") !== 0) {
                    editor.statusText = "Save cancelled";
                    return;
                }
                deliver.args = ["save", saver.rendered,
                                Model.withExtension(dest, Model.exportExtension(doc.format)),
                                doc.format, String(doc.quality),
                                String(doc.outWidth), String(doc.outHeight), doc.saveCopies ? "1" : "0"];
                deliver.running = true;
            }
        }
    }

    // The overlay steps aside for the dialog, as it does to open a picture.
    function pickLogo() {
        if (logoPicker.running) return "busy";
        picking = true;
        logoPicker.running = true;
        return "ok";
    }

    Process {
        id: logoPicker
        command: ["bash", root.pluginDir + "bin/postcard-logo", root.shotDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                root.picking = false;
                if (p.indexOf("/") === 0) doc.watermarkLogo = p;
                root.focusEditor();
            }
        }
    }

    Process {
        id: picker
        property bool append: false
        command: ["bash", root.pluginDir + "bin/postcard-pick", "open", root.shotDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                root.picking = false;
                if (p.length && p.indexOf("/") === 0) {
                    if (picker.append) root.addShot(p); else root.loadShot(p);
                }
                root.focusEditor();
            }
        }
    }
}
