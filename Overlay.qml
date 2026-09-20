import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "ui"
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

    readonly property string pluginId: manifest && manifest.id ? manifest.id : "tahayvr.omasnap"
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
        command: ["bash", root.pluginDir + "bin/snap-theme"]
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
        command: ["bash", root.pluginDir + "bin/snap-themes"]
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
        command: ["bash", root.pluginDir + "bin/snap-theme", theme]
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
        command: ["bash", root.pluginDir + "bin/snap-wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: doc.desktopBg = text.trim()
        }
    }

    function open(payloadJson) {
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
            capture(String(payload.capture));
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
        doc.selectedId = "";
    }

    function dismiss() {
        close();
        if (shell && typeof shell.hide === "function") shell.hide(pluginId);
    }

    // Public: edit, capture, save, copy, redact, copyText (see README, Scripting).
    function edit(path) {
        if (!path) return "no path";
        if (shell && typeof shell.summon === "function"
                && shell.summon(pluginId, JSON.stringify({ path: String(path) })))
            return "ok";
        open(JSON.stringify({ path: String(path) }));
        return "ok";
    }

    // set <json>: change document settings, e.g. {"padding": 8, "codeTheme": "nord"}.
    readonly property var settable: ["bgMode", "bgSolid", "bgGradient", "padding", "inset", "balance", "ratio",
        "radius", "shadow", "frame", "frameTitle", "exportScale", "format",
        "quality", "tool", "inkColor", "inkWidth", "codeLang", "codeTheme", "codeFont", "codeNumbers"]
    function set(json) {
        var o;
        try { o = JSON.parse(json); } catch (e) { return "bad json"; }
        var applied = 0;
        for (var k in o) if (settable.indexOf(k) !== -1) { doc[k] = o[k]; applied++; }
        return applied ? "ok" : "nothing to set";
    }

    // annotate <json>: add annotations in screenshot pixels: one object
    // {kind, x, y, w, h, color, width, text, index, strength}, or several as
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
            a.text = o.text ? String(o.text) : "";
            a.strength = Number(o.strength) || Math.max(6, Math.round(doc.geo.shotW / 90));
            if (a.kind === "step") {
                doc.stepCounter += 1;
                a.index = Number(o.index) || doc.stepCounter;
                if (!a.w) {
                    var size = Math.max(22, Math.round(a.width * 9));
                    a.x -= size / 2; a.y -= size / 2; a.w = size; a.h = size;
                }
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
            kind: doc.kind, opened: opened, capturing: capturing, picking: picking, busy: editor.busy, hasContent: doc.hasContent,
            shotPath: doc.shotPath, shotWidth: doc.shotWidth, shotHeight: doc.shotHeight,
            outWidth: doc.outWidth, outHeight: doc.outHeight, annotations: doc.annotations.count,
            bgMode: doc.bgMode, ratio: doc.ratio, padding: doc.padding, inset: doc.inset,
            frame: doc.frame, shotEdge: doc.shotEdge,
            codeLang: doc.codeLang, codeDetected: doc.codeDetected, codeTheme: doc.codeTheme,
            codeFont: doc.codeFont, codeNumbers: doc.codeNumbers, codeBg: String(doc.codeBg),
            codeFg: String(doc.codeFg), codeHtmlLength: doc.codeHtml.length
        });
    }

    // pick: open the system file dialog (the overlay hides so it is reachable).
    function pick() {
        if (picker.running) return "busy";
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
        command: ["bash", root.pluginDir + "bin/snap-text"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length) {
                    root.loadCode(text);
                } else if (!doc.hasContent) {
                    root.dismiss();
                } else {
                    editor.statusText = "Nothing is selected";
                }
                root.focusEditor();
            }
        }
    }

    function loadCode(text) {
        text = text.replace(/\r/g, "").replace(/\n+$/, "");
        if (!text.length) return;
        doc.clearAnnotations();
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
        command: ["bash", root.pluginDir + "bin/snap-highlight", doc.codeEffectiveLang,
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

    function loadShot(path) {
        if (!path) return;
        doc.clearAnnotations();
        doc.kind = "shot";
        doc.codeText = "";
        doc.codeHtml = "";
        doc.shotWidth = 0;
        doc.shotHeight = 0;
        doc.shotPath = path;
        doc.shotRevision += 1;
        doc.frameTitle = path.split("/").pop();
        doc.autoPalette = [];
        doc.shotPalette = [];
        doc.shotEdge = "";
        probe.source = "";
        probe.source = doc.shotUrl;
        paletteProc.path = path;
        paletteProc.running = true;
        edgeProc.path = path;
        edgeProc.running = true;
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
                editor.statusText = implicitWidth + "×" + implicitHeight + " loaded";
            } else if (status === Image.Error) {
                editor.statusText = "Could not open that image";
            }
        }
    }

    Process {
        id: dirProc
        command: ["bash", root.pluginDir + "bin/snap-dir"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = text.trim();
                if (d.length && d.indexOf("/") === 0) root.shotDir = d;
            }
        }
    }

    function capture(mode) {
        if (captureProc.running) return "busy";
        var m = String(mode || "region");
        if (["region", "windows", "fullscreen", "smart"].indexOf(m) === -1) m = "region";
        opened = true;
        capturing = true;
        captureProc.mode = m;
        hideTimer.restart();
        return "ok";
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

    Timer {
        id: hideTimer
        interval: 140      // let the layer surface actually leave the screen
        onTriggered: captureProc.running = true
    }

    Process {
        id: captureProc
        property string mode: "region"
        command: ["bash", root.pluginDir + "bin/snap-capture", mode]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var path = lines[lines.length - 1].trim();
                root.capturing = false;
                if (path.length > 0 && path.indexOf("/") === 0) {
                    root.loadShot(path);
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
        command: ["bash", root.pluginDir + "bin/snap-palette", path]
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
        command: ["bash", root.pluginDir + "bin/snap-edge", path]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim();
                doc.shotEdge = /^#[0-9a-fA-F]{6}$/.test(c) ? c : "";
            }
        }
    }

    Process {
        id: ocrProc
        property string purpose: "redact"
        command: ["bash", root.pluginDir + "bin/snap-ocr", doc.shotPath, purpose]
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
        command: ["bash", root.pluginDir + "bin/snap-deliver", "text"]
        stdinEnabled: true
        // Closing stdin ends the input; reopen it so the next run can write.
        onRunningChanged: {
            if (running) { write(text); stdinEnabled = false; }
            else stdinEnabled = true;
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

        Qt.callLater(function () {
            var target = editor.exportTarget;
            var size = Qt.size(target.width * doc.exportScale, target.height * doc.exportScale);
            var ok = target.grabToImage(function (result) {
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
                doc.exporting = false;
                editor.busy = false;
                editor.statusText = "Render failed — try a smaller export scale";
            }
        });
        return "ok";
    }

    function outputPath() {
        var ext = doc.format === "jpg" ? "jpg" : "png";
        return root.shotDir + "/snap-" + Model.stamp() + "." + ext;
    }

    function save() {
        return exportTo(root.scratchDir + "/omasnap-out.png", function (p) {
            deliver.args = ["save", p, outputPath(), doc.format, String(doc.quality),
                            String(doc.outWidth), String(doc.outHeight)];
            deliver.running = true;
        });
    }

    function copy() {
        return exportTo(root.scratchDir + "/omasnap-copy.png", function (p) {
            deliver.args = ["copy", p, "", doc.format, String(doc.quality),
                            String(doc.outWidth), String(doc.outHeight)];
            deliver.running = true;
        });
    }

    Process {
        id: deliver
        property var args: []
        command: ["bash", root.pluginDir + "bin/snap-deliver"].concat(args)
        stdout: StdioCollector {
            onStreamFinished: {
                var msg = text.trim();
                if (msg.length) editor.statusText = msg;
            }
        }
    }

    function editSelectedText(event) {
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
        if (event.text && event.text.length && event.text.charCodeAt(0) >= 32) {
            doc.annotations.setProperty(i, "text", a.text + event.text);
            doc.annotationsEdited();
            return true;
        }
        return false;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (doc.selectedId !== "") doc.selectedId = "";
            else root.dismiss();
            return true;
        }

        if (editSelectedText(event)) return true;

        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (doc.selectedId === "") return false;
            doc.removeAnnotation(doc.selectedId);
            return true;
        }

        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            case Qt.Key_C: root.copy(); return true;
            case Qt.Key_S: root.save(); return true;
            case Qt.Key_Z: doc.undo(); return true;
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
        if (map[event.key] !== undefined) {
            doc.tool = map[event.key];
            doc.selectedId = "";
            return true;
        }
        return false;
    }

    PanelWindow {
        id: window
        visible: root.opened && !root.capturing && !root.picking
        color: "transparent"

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "omasnap"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) root.focusEditor()

        Rectangle {
            anchors.fill: parent
            color: Color.menu && Color.menu.scrim ? Color.menu.scrim : Qt.rgba(0, 0, 0, 0.55)
            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }
        }

        // A floating card, not a full-screen takeover; the scrim shows the
        // desktop behind it and a click there closes the editor.
        FocusScope {
            id: scope
            anchors.centerIn: parent
            width: Math.min(Style.space(1320), parent.width - Style.gapsOut * 4)
            height: Math.min(Style.space(860), parent.height - Style.gapsOut * 4)
            focus: true

            Editor {
                id: editor
                anchors.fill: parent
                doc: doc
                systemThemes: root.systemThemes
                radius: 0

                onCaptureRequested: function (mode) { root.capture(mode); }
                onCodeRequested: root.code()
                onCloseRequested: root.dismiss()
                onCopyRequested: root.copy()
                onSaveRequested: root.save()
                onOpenRequested: root.pick()
                onAutoRedactRequested: root.redact()
                onCopyTextRequested: root.copyText()
            }

            Keys.onPressed: function (event) {
                if (root.handleKey(event)) event.accepted = true;
            }
        }
    }

    Process {
        id: picker
        command: ["bash", root.pluginDir + "bin/snap-pick", root.shotDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                root.picking = false;
                if (p.length && p.indexOf("/") === 0) root.loadShot(p);
                root.focusEditor();
            }
        }
    }
}
