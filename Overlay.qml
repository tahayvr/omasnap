import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "ui"
import "lib/Redact.js" as Redact
import "lib/Model.js" as Model

Item {
    id: root

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null

    property bool opened: false
    property bool capturing: false

    readonly property string pluginId: manifest && manifest.id ? manifest.id : "tahayvr.omasnap"
    readonly property string pluginDir: decodeURIComponent(
        Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""))

    property string shotDir: Quickshell.env("HOME") + "/Pictures"

    readonly property string scratchDir: {
        var d = Quickshell.env("XDG_RUNTIME_DIR");
        return d && d.length ? d : "/tmp";
    }

    Doc { id: doc }

    Component.onCompleted: dirProc.running = true

    function open(payloadJson) {
        var payload = {};
        try { payload = payloadJson ? JSON.parse(payloadJson) : {}; } catch (e) { payload = {}; }
        if (!payload || typeof payload !== "object") payload = {};

        opened = true;

        if (payload.path) {
            loadShot(String(payload.path));
        } else if (payload.capture) {
            capture(String(payload.capture));
        } else if (!doc.hasShot) {
            capture("region");
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

    function focusEditor() {
        Qt.callLater(function () { if (window.visible) scope.forceActiveFocus(); });
    }

    function loadShot(path) {
        if (!path) return;
        doc.clearAnnotations();
        doc.shotWidth = 0;
        doc.shotHeight = 0;
        doc.shotPath = path;
        doc.frameTitle = path.split("/").pop();
        doc.autoPalette = [];
        probe.source = "";
        probe.source = "file://" + path;
        paletteProc.path = path;
        paletteProc.running = true;
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
        if (!doc.hasShot) return "no shot";
        if (ocrProc.running) return "busy";
        editor.busy = true;
        editor.statusText = "Reading the screenshot…";
        ocrProc.purpose = "redact";
        ocrProc.running = true;
        return "ok";
    }

    function copyText() {
        if (!doc.hasShot) return "no shot";
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
        command: ["bash", root.pluginDir + "bin/snap-capture", mode, root.shotDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var path = lines[lines.length - 1].trim();
                root.capturing = false;
                if (path.length > 0 && path.indexOf("/") === 0) {
                    root.loadShot(path);
                } else if (!doc.hasShot) {
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
                var colors = text.trim().split("\n").filter(function (l) {
                    return /^#[0-9a-fA-F]{6}$/.test(l.trim());
                });
                doc.autoPalette = colors.slice(0, 5);
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
            if (code === 2) editor.statusText = "OCR needs tesseract installed";
            else if (code !== 0) editor.statusText = "OCR failed";
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
        onRunningChanged: {
            if (running) { write(text); stdinEnabled = false; }
        }
    }

    function exportTo(path, andThen) {
        if (!doc.hasShot) return "no shot";
        if (editor.busy) return "busy";
        if (doc.outputTooLarge) {
            editor.statusText = "Too large to render — pick a smaller export scale";
            return "too large";
        }
        editor.busy = true;
        doc.exporting = true;

        Qt.callLater(function () {
            var target = editor.exportTarget;
            var size = Model.grabSize(doc.outWidth, doc.outHeight, scope.dpr);
            var ok = target.grabToImage(function (result) {
                var wrote = result.saveToFile(path);
                doc.exporting = false;
                editor.busy = false;
                if (!wrote) {
                    editor.statusText = "Could not write " + path;
                    return;
                }
                if (andThen) andThen(path);
            }, Qt.size(size.w, size.h));

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
            deliver.args = ["save", p, outputPath(), doc.format, String(doc.quality)];
            deliver.running = true;
        });
    }

    function copy() {
        return exportTo(root.scratchDir + "/omasnap-copy.png", function (p) {
            deliver.args = ["copy", p, "", doc.format, String(doc.quality)];
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
        visible: root.opened && !root.capturing
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

        FocusScope {
            id: scope
            anchors.fill: parent
            // Match Hyprland's gaps_out so the editor lines up with tiled windows.
            anchors.margins: Style.gapsOut
            focus: true

            // The window's effective ratio (1.6 on a fractional scale), not the
            // integer one Screen reports. See Model.grabSize.
            readonly property real dpr: {
                var w = scope.Window.window;
                if (w && w.devicePixelRatio > 0) return w.devicePixelRatio;
                return Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1;
            }

            Editor {
                id: editor
                anchors.fill: parent
                doc: doc
                radius: 0

                onCaptureRequested: function (mode) { root.capture(mode); }
                onCloseRequested: root.dismiss()
                onCopyRequested: root.copy()
                onSaveRequested: root.save()
                onOpenRequested: picker.running = true
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
                if (p.length && p.indexOf("/") === 0) root.loadShot(p);
                root.focusEditor();
            }
        }
    }
}
