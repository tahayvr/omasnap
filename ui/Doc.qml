import QtQuick
import "../lib/Model.js" as Model

QtObject {
    id: doc

    // A document is either a screenshot or a code card. Both report their
    // pixel size through shotWidth/shotHeight so the frame maths is shared.
    property string kind: "shot"            // shot | code
    property string shotPath: ""
    property string shotName: ""            // what to call it, whatever a crop is pointing at
    property int shotWidth: 0
    property int shotHeight: 0
    // Bumped on every load so a file that changed under the same path gets
    // a URL Qt's image cache has not seen. Without it, recapturing to the
    // same name reopened the previous picture, at the previous size.
    property int shotRevision: 0
    readonly property url shotUrl: shotPath
        ? "file://" + shotPath + "#v" + shotRevision : ""
    readonly property bool hasContent: (kind === "code" ? codeText !== "" : shotPath !== "") && shotWidth > 0

    property string codeText: ""
    property string codeHtml: ""
    property string codeLang: "auto"
    property string codeDetected: "txt"     // what "auto" resolved to
    readonly property string codeEffectiveLang: codeLang === "auto" ? codeDetected : codeLang
    property string codeTheme: "omarchy"
    property int codeFont: 16
    property bool codeNumbers: false
    property color codeBg: "#1e222a"
    property color codeFg: "#e6e6e6"
    readonly property int codePad: Math.round(codeFont * 1.6)

    property string bgMode: "auto"          // auto | solid | gradient | theme | desktop | none
    property color bgSolid: "#1e222a"
    property string bgGradient: "dusk"
    property string desktopBg: ""          // the wallpaper, bin/postcard-wallpaper
    property int bgAngle: 135
    // The "custom" gradient on show, held by value so it stays on the card
    // even if the saved gradient it came from is deleted; bgCustomId names
    // that saved gradient, so edits reach it too.
    property var bgCustomStops: Model.CUSTOM_STOPS
    property int bgCustomAngle: Model.CUSTOM_ANGLE
    property string bgCustomId: ""
    // The user's own, kept on disk by the overlay rather than reset with the
    // rest of the styling: solid colors and gradients, newest first.
    property var customColors: []
    // Annotation inks of the user's own, kept apart from the background
    // colors: inks are bright where backgrounds are mostly muted.
    property var inkColors: []

    // Preferences, from Model.DEFAULT_SETTINGS; the overlay keeps them in
    // settings.json.
    property bool saveCopies: true
    property var userGradients: []

    // Saved looks, kept on disk by the overlay like the colors; the one in
    // use is remembered too, so it is still in use after a restart.
    property var presets: []
    property string activePreset: Model.DEFAULT_PRESET
    readonly property var activePresetEntry: Model.findPreset(presets, activePreset)
                                             || Model.findPreset([], Model.DEFAULT_PRESET)
    // Whether the card has been changed since the preset was put on it.
    // styleOf reads every setting, so this follows each of them.
    readonly property bool presetModified: !Model.sameStyle(Model.styleOf(doc), activePresetEntry.style)
    property var autoPalette: []            // backdrop colors, bin/postcard-palette
    property var shotPalette: []            // the same colors as they appear in the shot
    property string shotEdge: ""            // the shot's edge color, bin/postcard-edge

    property real padding: 5                // percent of the shot's longest edge
    property real inset: 0                  // same units, inside the card
    property bool balance: false            // off unless asked for
    property string ratio: "auto"

    property real radius: 3                 // percent of the card's shorter edge
    property real shadow: 45                // one control: spread, drop, opacity
    property string frame: "none"           // none | titlebar

    // A handle and/or a logo under the card's bottom-right corner. The logo
    // is a copy kept in ~/.config/postcard/logos, so a preset that names it
    // does not break when the original moves.
    property string watermarkText: ""
    property string watermarkLogo: ""
    property real watermarkSize: 100        // percent of the size that suits the card
    readonly property bool hasWatermark: watermarkText !== "" || watermarkLogo !== ""
    property string frameTitle: ""

    property int exportScale: 1
    property string format: "png"
    property int quality: 92

    property string tool: "select"
    property color inkColor: "#ff5f56"
    property real inkWidth: 4
    property string arrowStyle: "straight"
    property string textFont: "mono"
    property int magnifyZoom: Model.MAGNIFY_ZOOM
    property int stepCounter: 0
    // The size a label was last pulled to, so the next one matches; 0 until
    // then, and a size that suits one shot may not suit the next.
    property int textSize: 0
    // selectedId is the mark in hand: the one with handles, and the one the
    // tool bar shows. selectedIds is everything selected, that one included.
    // Assigning selectedId selects that mark alone; selectMany keeps a set.
    property string selectedId: ""
    property var selectedIds: []
    property bool _keepingSet: false
    // A group follows the one mark being dragged by this much, and only
    // takes the move into the model on release.
    property string groupLeader: ""
    property point groupShift: Qt.point(0, 0)
    // Undo and redo step through snapshots of every mark, taken once the
    // marks have been still for a moment (settle) and nothing is held down:
    // a drag or a burst of typing is one step, and every way of changing a
    // mark is covered without each keeping its own record. The history is
    // the picture's: a new one, or a crop, starts it again.
    property var history: []
    property int historyAt: -1
    property bool historyPending: false
    property bool _restoring: false
    // A press under way on the picture; a snapshot waits for it to end.
    property bool pressing: false
    readonly property bool canUndo: historyAt > 0 || historyPending
    readonly property bool canRedo: !historyPending && historyAt < history.length - 1
    Component.onCompleted: resetHistory()
    property Timer settle: Timer {
        interval: 450
        onTriggered: doc.settleHistory()
    }
    // Marks copied with Ctrl+C, as plain values. They belong to this picture,
    // so a new one clears them. Each paste lands a step further along.
    property var markClipboard: []
    property int pasteCount: 0

    property var redactClasses: ["email", "secret", "card", "net", "phone"]

    // The shots on the card (Model.newSlot), each the file it came from and
    // its own crop in that file, so a crop never touches a file and can be
    // widened again or dropped. The picture on show (shotPath) is the first
    // file itself while there is one shot and no crop, and otherwise a sheet
    // composed from them all (bin/postcard-sheet), laid out by `sheet`.
    // Both change together, only once the new picture is ready: the
    // overlay commits them.
    property var slots: []
    property var sheet: null
    readonly property int shotCount: slots.length
    readonly property bool cropped: slots.some(function (s) { return !!s.crop; })
    // How several shots are laid out. Changing these asks the overlay to
    // lay the shots out again.
    property string layoutDir: "row"          // row | column
    property real slotGap: Model.SLOT_GAP
    property bool matchSizes: true
    property string slotAlign: "center"       // start | center | end
    property rect cropRect: Qt.rect(0, 0, 0, 0)   // the selection being drawn
    readonly property bool cropUsable: Model.cropUsable(cropRect)

    property string spotShape: "rect"       // rect | ellipse, for every spotlight
    property real spotDim: 55               // how dark the rest of the picture goes
    property int spotlightCount: 0
    // A ListModel emits nothing a binding can follow, so the dim layer and the
    // count above ride on this instead.
    property int annotationRevision: 0

    // True for the grab frame; editing affordances bind to it.
    property bool exporting: false

    property ListModel annotations: ListModel { dynamicRoles: true }

    readonly property var geo: Model.frameGeometry({
        shotWidth: doc.shotWidth,
        shotHeight: doc.shotHeight,
        baseWidth: doc.shotCount > 1 && doc.sheet ? doc.sheet.baseW : 0,
        baseHeight: doc.shotCount > 1 && doc.sheet ? doc.sheet.baseH : 0,
        padding: doc.padding,
        inset: doc.inset,
        ratio: doc.ratio,
        balance: doc.balance,
        frame: doc.frame
    })

    readonly property int outWidth: Math.round(geo.frameW * exportScale)
    readonly property int outHeight: Math.round(geo.frameH * exportScale)
    readonly property bool outputTooLarge: outWidth > Model.MAX_OUTPUT_SIDE
                                           || outHeight > Model.MAX_OUTPUT_SIDE

    // Not `annotationsChanged`: that name belongs to the property.
    signal annotationsEdited()

    onAnnotationsEdited: {
        var n = 0;
        for (var i = 0; i < annotations.count; i++)
            if (annotations.get(i).kind === "spotlight") n++;
        spotlightCount = n;
        annotationRevision++;
        if (!_restoring) {
            historyPending = true;
            settle.restart();
        }
    }

    property string _previousSelectedId: ""

    onSelectedIdChanged: {
        if (!_keepingSet) selectedIds = selectedId !== "" ? [selectedId] : [];
        var prev = _previousSelectedId;
        _previousSelectedId = selectedId;
        if (prev === "" || prev === selectedId) return;
        var i = indexOfId(prev);
        if (i < 0) return;
        var a = annotations.get(i);
        if (a.kind === "text" && a.text === "") {
            selectedIds = selectedIds.filter(function (u) { return u !== prev; });
            annotations.remove(i);
            annotationsEdited();
        }
    }

    function isSelected(uid) {
        return selectedIds.indexOf(uid) !== -1;
    }

    // A set of marks, with `primary` in hand, or the last of them if it is
    // not one.
    function selectMany(uids, primary) {
        var kept = uids.filter(function (u, n) {
            return indexOfId(u) !== -1 && uids.indexOf(u) === n;
        });
        _keepingSet = true;
        selectedIds = kept;
        selectedId = kept.length === 0 ? ""
                   : kept.indexOf(primary) !== -1 ? primary : kept[kept.length - 1];
        _keepingSet = false;
    }

    function toggleSelected(uid) {
        var s = selectedIds.slice();
        var n = s.indexOf(uid);
        if (n === -1) { s.push(uid); selectMany(s, uid); }
        else { s.splice(n, 1); selectMany(s, selectedId === uid ? "" : selectedId); }
    }

    function selectAll() {
        var s = [];
        for (var i = 0; i < annotations.count; i++) s.push(annotations.get(i).uid);
        selectMany(s, selectedId);
    }

    function selectInBox(x, y, w, h, adding) {
        var s = adding ? selectedIds.slice() : [];
        for (var i = 0; i < annotations.count; i++) {
            var a = annotations.get(i);
            if (Model.inSelectionBox(a, x, y, w, h)) s.push(a.uid);
        }
        selectMany(s, selectedId);
    }

    // Every selected row, as live rows, in the order they were drawn.
    function selectedRows() {
        var out = [];
        for (var i = 0; i < annotations.count; i++)
            if (isSelected(annotations.get(i).uid)) out.push(annotations.get(i));
        return out;
    }

    // Like a drag, a magnifier's lens moves and what it shows stays.
    function moveSelection(dx, dy, except) {
        if (dx === 0 && dy === 0) return;
        for (var i = 0; i < annotations.count; i++) {
            var a = annotations.get(i);
            if (a.uid === except || !isSelected(a.uid)) continue;
            annotations.setProperty(i, "x", a.x + dx);
            annotations.setProperty(i, "y", a.y + dy);
        }
        annotationsEdited();
    }

    // A label nothing was typed into is not worth a copy.
    function copySelection() {
        var rows = selectedRows().filter(function (a) { return !(a.kind === "text" && a.text === ""); });
        if (rows.length === 0) return 0;
        markClipboard = rows.map(Model.plainAnnotation);
        pasteCount = 0;
        return rows.length;
    }

    function paste() {
        return placeCopies(markClipboard, ++pasteCount);
    }

    // Copies of the selection beside it, leaving the clipboard alone.
    function duplicateSelection() {
        var rows = selectedRows().filter(function (a) { return !(a.kind === "text" && a.text === ""); });
        return placeCopies(rows.map(Model.plainAnnotation), 1);
    }

    function placeCopies(marks, steps) {
        if (marks.length === 0) return 0;
        var d = Model.pasteStep(shotWidth, shotHeight) * steps;
        var made = marks.map(function (a) { return Model.duplicateAnnotation(a, d, d); });
        made.forEach(function (a) { annotations.append(a); });
        renumberSteps();
        selectMany(made.map(function (a) { return a.uid; }), made[made.length - 1].uid);
        annotationsEdited();
        return made.length;
    }

    function removeSelection() {
        var gone = selectedIds.slice();
        if (gone.length === 0) return 0;
        selectedId = "";
        for (var i = annotations.count - 1; i >= 0; i--)
            if (gone.indexOf(annotations.get(i).uid) !== -1) annotations.remove(i);
        renumberSteps();
        annotationsEdited();
        return gone.length;
    }

    function addAnnotation(obj) {
        annotations.append(obj);
        selectedId = obj.uid;
        annotationsEdited();
    }

    // What the next arrow will be, and the one just drawn: an arrow is
    // selected the moment it is finished, so the choice reads as live.
    function setArrowStyle(key) {
        arrowStyle = key;
        selectedRows().forEach(function (a) {
            if (a.kind === "arrow") updateAnnotation(a.uid, { style: key });
        });
    }

    // The font for the next label and for the one in hand, like the arrow style.
    function setTextFont(key) {
        textFont = key;
        selectedRows().forEach(function (a) {
            if (a.kind === "text") updateAnnotation(a.uid, { font: key });
        });
    }

    // Like the arrow style, the zoom is for the next magnifier and the one
    // in hand.
    function setMagnifyZoom(z) {
        magnifyZoom = Model.magnifyZoom(z);
        selectedRows().forEach(function (a) {
            if (a.kind === "magnify") updateAnnotation(a.uid, Model.magnifyRezoom(a, magnifyZoom));
        });
    }

    // A crop moves the picture out from under everything drawn on it, a
    // magnifier's area as well as its lens.
    function shiftAnnotations(dx, dy) {
        if (dx === 0 && dy === 0) return;
        for (var i = 0; i < annotations.count; i++) {
            var a = annotations.get(i);
            annotations.setProperty(i, "x", a.x + dx);
            annotations.setProperty(i, "y", a.y + dy);
            if (a.kind === "magnify") {
                annotations.setProperty(i, "sx", a.sx + dx);
                annotations.setProperty(i, "sy", a.sy + dy);
            }
        }
        annotationsEdited();
    }

    // The tool bar edits whatever is in hand: every selected mark, and
    // always the setting the next mark will be made with.
    function styleSelection(prop, value) {
        var rows = selectedRows();
        var patch = {};
        patch[prop] = value;
        rows.forEach(function (a) { updateAnnotation(a.uid, patch); });
        return rows.length > 0;
    }

    // What a crop cuts away takes the marks that were only on it.
    function dropOutside(w, h) {
        var gone = 0;
        for (var i = annotations.count - 1; i >= 0; i--) {
            var a = annotations.get(i);
            if (Model.overlapsRect(a, 0, 0, w, h)) continue;
            if (selectedId === a.uid) selectedId = "";
            else if (isSelected(a.uid))
                selectMany(selectedIds.filter(function (u) { return u !== a.uid; }), selectedId);
            annotations.remove(i);
            gone++;
        }
        if (gone > 0) {
            renumberSteps();
            annotationsEdited();
        }
        return gone;
    }

    function indexOfId(uid) {
        for (var i = 0; i < annotations.count; i++)
            if (annotations.get(i).uid === uid) return i;
        return -1;
    }

    function selectedAnnotation() {
        var i = indexOfId(selectedId);
        return i < 0 ? null : annotations.get(i);
    }

    function updateAnnotation(uid, patch) {
        var i = indexOfId(uid);
        if (i < 0) return;
        annotations.set(i, patch);
        annotationsEdited();
    }

    function removeAnnotation(uid) {
        var i = indexOfId(uid);
        if (i < 0) return;
        if (selectedId === uid) selectedId = "";
        else if (isSelected(uid))
            selectMany(selectedIds.filter(function (u) { return u !== uid; }), selectedId);
        annotations.remove(i);
        renumberSteps();
        annotationsEdited();
    }

    // Steps are read as a sequence, so losing one in the middle must not
    // leave a hole in it: the rest close up, in the order they were made,
    // and the next one carries on from the end.
    function renumberSteps() {
        var n = 0;
        for (var i = 0; i < annotations.count; i++) {
            if (annotations.get(i).kind !== "step") continue;
            n++;
            if (annotations.get(i).index !== n) annotations.setProperty(i, "index", n);
        }
        stepCounter = n;
        return n;
    }

    function clearAnnotations() {
        selectedId = "";
        annotations.clear();
        stepCounter = 0;
        annotationsEdited();
    }

    // The marks as plain values. A label nothing was typed into is left
    // out: it is not there until it says something.
    function snapshot() {
        var out = [];
        for (var i = 0; i < annotations.count; i++) {
            var a = annotations.get(i);
            if (a.kind === "text" && a.text === "") continue;
            out.push(Model.plainAnnotation(a));
        }
        return JSON.stringify(out);
    }

    // Records the marks as they are, if they have changed since the last
    // step. Anything after the current step is gone once something new
    // happens, as redo would land on a different picture.
    function checkpoint() {
        settle.stop();
        historyPending = false;
        var s = snapshot();
        if (historyAt >= 0 && history[historyAt] === s) return;
        var h = history.slice(0, historyAt + 1);
        h.push(s);
        if (h.length > Model.HISTORY_KEPT) h = h.slice(h.length - Model.HISTORY_KEPT);
        history = h;
        historyAt = h.length - 1;
    }

    function settleHistory() {
        if (pressing) { settle.restart(); return; }
        checkpoint();
    }

    // The picture as it is now is where undo stops.
    function resetHistory() {
        settle.stop();
        historyPending = false;
        history = [snapshot()];
        historyAt = 0;
    }

    function restore(s) {
        _restoring = true;
        replaceAnnotations(JSON.parse(s));
        _restoring = false;
    }

    // Every mark at once, as plain values: a snapshot, or the marks moved to
    // a new layout of the shots.
    function replaceAnnotations(list) {
        selectedId = "";
        groupLeader = "";
        annotations.clear();
        list.forEach(function (a) { annotations.append(a); });
        renumberSteps();
        annotationsEdited();
    }

    // An edit still settling counts: it is recorded first, then undone.
    function undo() {
        if (pressing) return false;
        checkpoint();
        if (historyAt <= 0) return false;
        historyAt--;
        restore(history[historyAt]);
        return true;
    }

    function redo() {
        if (pressing) return false;
        checkpoint();
        if (historyAt >= history.length - 1) return false;
        historyAt++;
        restore(history[historyAt]);
        return true;
    }

    // Back to the empty state; styling settings are kept.
    function clearContent() {
        clearAnnotations();
        kind = "shot";
        shotPath = "";
        shotWidth = 0;
        shotHeight = 0;
        codeText = "";
        codeHtml = "";
        shotName = "";
        slots = [];
        sheet = null;
        cropRect = Qt.rect(0, 0, 0, 0);
        frameTitle = "";
        autoPalette = [];
        shotPalette = [];
        shotEdge = "";
        textSize = 0;
        markClipboard = [];
        pasteCount = 0;
        resetHistory();
    }

    // Every styling setting back to its default; content and title stay.
    function reset() {
        clearAnnotations();
        applyStyle(Model.DEFAULT_STYLE);
        activePreset = Model.DEFAULT_PRESET;
        tool = "select";
        spotShape = "rect"; spotDim = 55;
        inkColor = "#ff5f56"; inkWidth = 4; arrowStyle = "straight"; textFont = "mono";
        magnifyZoom = Model.MAGNIFY_ZOOM;
    }

    function applyStyle(style) {
        var s = Model.cleanStyle(style);
        for (var i = 0; i < Model.STYLE_KEYS.length; i++)
            doc[Model.STYLE_KEYS[i]] = s[Model.STYLE_KEYS[i]];
        // Held by value in the preset, so no saved gradient is being edited.
        bgCustomId = "";
    }

    function applyPreset(key) {
        var p = Model.findPreset(presets, key);
        if (!p) return false;
        applyStyle(p.style);
        activePreset = p.id;
        return true;
    }

    // Saving under a name that is taken updates that preset rather than
    // making a second one with the same name.
    function savePresetAs(name) {
        var clean = Model.cleanPresetName(name);
        if (!clean || clean.toLowerCase() === Model.DEFAULT_PRESET) return "";
        var same = Model.findPreset(presets, clean);
        var p = { id: same ? same.id : Model.newGradientId(), name: clean, style: Model.styleOf(doc) };
        presets = Model.savePreset(presets, p);
        activePreset = p.id;
        return p.id;
    }

    function updatePreset() {
        if (activePreset === Model.DEFAULT_PRESET) return false;
        var p = Model.findPreset(presets, activePreset);
        if (!p) return false;
        presets = Model.savePreset(presets, { id: p.id, name: p.name, style: Model.styleOf(doc) });
        return true;
    }

    // The card keeps its look; it is simply no longer that preset.
    function deletePreset(id) {
        presets = Model.forgetPreset(presets, id);
        if (activePreset === id) activePreset = Model.DEFAULT_PRESET;
    }
}
