import QtQuick
import "../lib/Model.js" as Model

QtObject {
    id: doc

    // A document is either a screenshot or a code card. Both report their
    // pixel size through shotWidth/shotHeight so the frame maths is shared.
    property string kind: "shot"            // shot | code
    property string shotPath: ""
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
    property string desktopBg: ""          // the wallpaper, bin/snap-wallpaper
    property int bgAngle: 135
    property var autoPalette: []            // backdrop colors, bin/snap-palette
    property var shotPalette: []            // the same colors as they appear in the shot
    property string shotEdge: ""            // the shot's edge color, bin/snap-edge

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
    property int stepCounter: 0
    property string selectedId: ""

    property var redactClasses: ["email", "secret", "card", "net", "phone"]

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
        annotations.append(obj);
        selectedId = obj.uid;
        annotationsEdited();
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
        annotationsEdited();
    }

    function clearAnnotations() {
        selectedId = "";
        annotations.clear();
        stepCounter = 0;
        annotationsEdited();
    }

    function undo() {
        if (annotations.count === 0) return;
        selectedId = "";
        var last = annotations.get(annotations.count - 1);
        if (last.kind === "step") stepCounter = Math.max(0, stepCounter - 1);
        annotations.remove(annotations.count - 1);
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
        frameTitle = "";
        autoPalette = [];
        shotPalette = [];
        shotEdge = "";
    }

    function reset() {
        clearAnnotations();
        padding = 5; inset = 0; ratio = "auto"; balance = false;
        radius = 3; shadow = 45;
        frame = "none"; bgMode = "auto"; tool = "select";
        codeFont = 16; codeNumbers = false;
    }
}
