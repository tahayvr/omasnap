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
    property string frameTitle: ""

    property int exportScale: 1
    property string format: "png"
    property int quality: 92

    property string tool: "select"
    property color inkColor: "#ff5f56"
    property real inkWidth: 4
    property string arrowStyle: "straight"
    property int magnifyZoom: Model.MAGNIFY_ZOOM
    property int stepCounter: 0
    // The size a label was last pulled to, so the next one matches; 0 until
    // then, and a size that suits one shot may not suit the next.
    property int textSize: 0
    property string selectedId: ""
    // What undo took away, newest last. Any other change to the marks
    // empties it, since a redo would then land on a different picture.
    property var redoStack: []

    property var redactClasses: ["email", "secret", "card", "net", "phone"]

    // Cropping never touches the file it started from: the picture on show is
    // a fresh cut of cropSource, and cropOffset says how far it has moved, so
    // the crop can be widened again or dropped entirely.
    property string cropSource: ""
    property point cropOffset: Qt.point(0, 0)
    property bool cropped: false
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
    }

    property string _previousSelectedId: ""

    onSelectedIdChanged: {
        var prev = _previousSelectedId;
        _previousSelectedId = selectedId;
        if (prev === "" || prev === selectedId) return;
        var i = indexOfId(prev);
        if (i < 0) return;
        var a = annotations.get(i);
        if (a.kind === "text" && a.text === "") {
            annotations.remove(i);
            annotationsEdited();
        }
    }

    function addAnnotation(obj) {
        redoStack = [];
        annotations.append(obj);
        selectedId = obj.uid;
        annotationsEdited();
    }

    // What the next arrow will be, and the one just drawn: an arrow is
    // selected the moment it is finished, so the choice reads as live.
    function setArrowStyle(key) {
        arrowStyle = key;
        var a = selectedAnnotation();
        if (a && a.kind === "arrow") updateAnnotation(a.uid, { style: key });
    }

    // Like the arrow style, the zoom is for the next magnifier and the one
    // in hand.
    function setMagnifyZoom(z) {
        magnifyZoom = Model.magnifyZoom(z);
        var a = selectedAnnotation();
        if (a && a.kind === "magnify") updateAnnotation(a.uid, Model.magnifyRezoom(a, magnifyZoom));
    }

    // A crop moves the picture out from under everything drawn on it, a
    // magnifier's area as well as its lens.
    function shiftAnnotations(dx, dy) {
        if (dx === 0 && dy === 0) return;
        redoStack = [];
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

    // The tool bar edits whatever is in hand: the selected mark if there is
    // one, and always the setting the next mark will be made with.
    function styleSelection(prop, value) {
        var a = selectedAnnotation();
        if (!a) return false;
        var patch = {};
        patch[prop] = value;
        updateAnnotation(a.uid, patch);
        return true;
    }

    // What a crop cuts away takes the marks that were only on it.
    function dropOutside(w, h) {
        redoStack = [];
        var gone = 0;
        for (var i = annotations.count - 1; i >= 0; i--) {
            var a = annotations.get(i);
            if (Model.overlapsRect(a, 0, 0, w, h)) continue;
            if (selectedId === a.uid) selectedId = "";
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
        redoStack = [];
        selectedId = "";
        annotations.clear();
        stepCounter = 0;
        annotationsEdited();
    }

    function undo() {
        if (annotations.count === 0) return;
        var last = Model.plainAnnotation(annotations.get(annotations.count - 1));
        // Deselecting drops a text mark nothing was typed into, and when that
        // is the last mark, dropping it is the whole undo. Removing by
        // position after it would have taken the mark before it as well.
        selectedId = "";
        var i = indexOfId(last.uid);
        if (i < 0) return;
        annotations.remove(i);
        redoStack = redoStack.concat([last]);
        renumberSteps();
        annotationsEdited();
    }

    function redo() {
        if (redoStack.length === 0) return;
        var a = redoStack[redoStack.length - 1];
        redoStack = redoStack.slice(0, -1);
        annotations.append(a);
        renumberSteps();
        selectedId = a.uid;
        annotationsEdited();
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
        cropSource = "";
        cropOffset = Qt.point(0, 0);
        cropped = false;
        cropRect = Qt.rect(0, 0, 0, 0);
        frameTitle = "";
        autoPalette = [];
        shotPalette = [];
        shotEdge = "";
        textSize = 0;
    }

    // Every styling setting back to its default; content and title stay.
    function reset() {
        clearAnnotations();
        applyStyle(Model.DEFAULT_STYLE);
        activePreset = Model.DEFAULT_PRESET;
        tool = "select";
        spotShape = "rect"; spotDim = 55;
        inkColor = "#ff5f56"; inkWidth = 4; arrowStyle = "straight";
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
