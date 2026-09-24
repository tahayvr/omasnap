import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../lib/Model.js" as Model

// The crop selection, in screenshot pixels over the picture: what stays
// bright is what will be kept. Editing chrome only — it is gated on the crop
// tool being in hand and never reaches the file.
Item {
    id: crop

    property var doc: null
    property real viewScale: 1

    readonly property rect sel: doc ? doc.cropRect : Qt.rect(0, 0, 0, 0)
    // Kept on through a drag that pulls the selection under the minimum, so
    // the picture does not flash while a corner is being brought in.
    readonly property bool drawn: doc !== null && (doc.cropUsable || grab.mode !== 0)
    readonly property real hairline: Math.max(1, 1.5 / crop.viewScale)
    // Screen sizes: a handle stays the same size on screen however far the
    // picture is scaled down to fit the viewport.
    readonly property real handle: 9 / crop.viewScale
    readonly property real grip: 13 / crop.viewScale

    visible: doc !== null && doc.tool === "crop" && !doc.exporting

    // 1 to 4 are the corners clockwise from the top left, 5 the inside, and
    // 6 to 9 the sides clockwise from the top. 0 is the bare picture, where
    // the press belongs to the tool underneath, which starts a new selection.
    // Corners win over sides, so a corner stays reachable however small the
    // selection gets.
    function at(px, py) {
        if (!crop.doc.cropUsable) return 0;
        var r = crop.sel;
        var x1 = r.x + r.width, y1 = r.y + r.height;
        function near(x, y) {
            return Math.abs(px - x) <= crop.grip && Math.abs(py - y) <= crop.grip;
        }
        if (near(r.x, r.y)) return 1;
        if (near(x1, r.y)) return 2;
        if (near(x1, y1)) return 3;
        if (near(r.x, y1)) return 4;
        var alongX = px >= r.x && px <= x1, alongY = py >= r.y && py <= y1;
        if (alongX && Math.abs(py - r.y) <= crop.grip) return 6;
        if (alongY && Math.abs(px - x1) <= crop.grip) return 7;
        if (alongX && Math.abs(py - y1) <= crop.grip) return 8;
        if (alongY && Math.abs(px - r.x) <= crop.grip) return 9;
        if (alongX && alongY) return 5;
        return 0;
    }

    // The edges a drag leaves where they are: those opposite the handle.
    function anchorX(mode) {
        return (mode === 2 || mode === 3 || mode === 7) ? crop.sel.x : crop.sel.x + crop.sel.width;
    }
    function anchorY(mode) {
        return (mode === 3 || mode === 4 || mode === 8) ? crop.sel.y : crop.sel.y + crop.sel.height;
    }

    // The drag itself, kept out of the mouse handlers so the harness can put
    // it through its paces without a pointer.
    function begin(px, py) {
        grab.mode = crop.at(px, py);
        grab.holdX = px - crop.sel.x;
        grab.holdY = py - crop.sel.y;
        // Taken once, and kept: read afresh each time, the far corner would
        // walk along with the selection the moment a drag crossed it.
        grab.anchorX = crop.anchorX(grab.mode);
        grab.anchorY = crop.anchorY(grab.mode);
        grab.start = crop.sel;
        return grab.mode;
    }

    function dragTo(px, py) {
        if (grab.mode === 0) return;
        var w = crop.doc.shotWidth, h = crop.doc.shotHeight;
        if (grab.mode === 5) {
            crop.doc.cropRect = Qt.rect(
                Math.round(Model.clamp(px - grab.holdX, 0, w - crop.sel.width)),
                Math.round(Model.clamp(py - grab.holdY, 0, h - crop.sel.height)),
                crop.sel.width, crop.sel.height);
            return;
        }
        // The edges opposite the handle stay put, and the normaliser squares
        // up a drag pulled past them. A side moves one edge only, so the
        // other axis keeps the span it had when the drag began.
        var ax = grab.anchorX, ay = grab.anchorY, s = grab.start;
        var r;
        if (grab.mode === 6 || grab.mode === 8)
            r = Model.cropRect(s.x, ay, s.width, py - ay, w, h);
        else if (grab.mode === 7 || grab.mode === 9)
            r = Model.cropRect(ax, s.y, px - ax, s.height, w, h);
        else
            r = Model.cropRect(ax, ay, px - ax, py - ay, w, h);
        crop.doc.cropRect = Qt.rect(r.x, r.y, r.w, r.h);
    }

    function finish() {
        // Pulled down to nothing, it is a selection no more.
        if (grab.mode !== 0 && !crop.doc.cropUsable)
            crop.doc.cropRect = Qt.rect(0, 0, 0, 0);
        grab.mode = 0;
    }

    // The same outline-with-a-hole the spotlight draws, for the same reason:
    // one filled path means the dim is even.
    Shape {
        anchors.fill: parent
        visible: crop.drawn
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: Qt.rgba(0, 0, 0, 0.55)
            strokeWidth: -1
            PathSvg {
                path: Model.spotlightPath(crop.width, crop.height, 0, 0,
                                          [{ x: crop.sel.x, y: crop.sel.y,
                                             w: crop.sel.width, h: crop.sel.height }])
            }
        }
    }

    Item {
        id: frame
        x: crop.sel.x
        y: crop.sel.y
        width: Math.max(1, crop.sel.width)
        height: Math.max(1, crop.sel.height)
        visible: crop.drawn

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Color.accent
            border.width: crop.hairline
        }

        // Thirds, the way a camera draws them.
        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: Math.round(frame.width * (index + 1) / 3)
                width: crop.hairline
                height: frame.height
                color: Qt.rgba(1, 1, 1, 0.28)
            }
        }
        Repeater {
            model: 2
            Rectangle {
                required property int index
                y: Math.round(frame.height * (index + 1) / 3)
                height: crop.hairline
                width: frame.width
                color: Qt.rgba(1, 1, 1, 0.28)
            }
        }

        // One at each corner, to pull the selection about.
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: (index === 1 || index === 2 ? frame.width : 0) - width / 2
                y: (index === 2 || index === 3 ? frame.height : 0) - height / 2
                width: crop.handle
                height: crop.handle
                color: Color.accent
                border.width: crop.hairline
                border.color: Qt.rgba(0, 0, 0, 0.55)
            }
        }

        // A bar at the middle of each side, clockwise from the top, left off
        // a side too short to hold one clear of its corners.
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property bool across: index === 0 || index === 2
                readonly property real length: crop.handle * 2.4
                width: across ? length : crop.handle * 0.7
                height: across ? crop.handle * 0.7 : length
                x: (index === 1 ? frame.width : index === 3 ? 0 : frame.width / 2) - width / 2
                y: (index === 2 ? frame.height : index === 0 ? 0 : frame.height / 2) - height / 2
                visible: (across ? frame.width : frame.height) > crop.handle * 5
                color: Color.accent
                border.width: crop.hairline
                border.color: Qt.rgba(0, 0, 0, 0.55)
            }
        }
    }

    // No wider than the selection and the reach around it, so the picture
    // beyond is left to the surface underneath, which starts a new selection.
    // Coordinates come in local to this, and go back out in the picture's.
    MouseArea {
        id: grab
        x: crop.sel.x - crop.grip
        y: crop.sel.y - crop.grip
        width: crop.sel.width + crop.grip * 2
        height: crop.sel.height + crop.grip * 2
        enabled: crop.visible && crop.doc.cropUsable
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        property int mode: 0
        property real holdX: 0        // where inside the selection it was taken
        property real holdY: 0
        property real anchorX: 0      // the edges this drag leaves alone
        property real anchorY: 0
        property rect start           // the selection as the drag found it

        cursorShape: {
            var m = grab.mode !== 0 ? grab.mode
                  : crop.at(grab.mouseX + grab.x, grab.mouseY + grab.y);
            if (m === 1 || m === 3) return Qt.SizeFDiagCursor;
            if (m === 2 || m === 4) return Qt.SizeBDiagCursor;
            if (m === 6 || m === 8) return Qt.SizeVerCursor;
            if (m === 7 || m === 9) return Qt.SizeHorCursor;
            if (m === 5) return Qt.SizeAllCursor;
            return Qt.CrossCursor;
        }

        onPressed: function (e) {
            if (crop.begin(e.x + grab.x, e.y + grab.y) === 0) e.accepted = false;
        }
        onPositionChanged: function (e) { crop.dragTo(e.x + grab.x, e.y + grab.y); }
        onReleased: crop.finish()
    }
}
