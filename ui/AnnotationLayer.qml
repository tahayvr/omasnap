import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../lib/Model.js" as Model

// Annotations live in screenshot pixel coordinates. Ids avoid `layer` and
// `item`: every Item has a `layer` property and Loader exposes `item`, and
// both would shadow an id inside the delegates.
Item {
    id: anno

    property var doc: null
    property Item pixelSource: null
    // The live editor, as against the export or the bar widget's preview.
    property bool interactive: false
    // With the move tool every mark is there to be taken. With a tool that
    // draws, only the one just drawn is, so a press anywhere else still
    // starts a new mark.
    readonly property bool moving: anno.doc !== null && anno.doc.tool === "select"
    // Cropping is about the picture, not the marks on it: the whole surface
    // belongs to the selection being drawn.
    readonly property bool editable: anno.interactive && anno.doc !== null
                                     && anno.doc.tool !== "crop"

    property real viewScale: 1

    // Screen sizes, so they stay put however far the picture is scaled down.
    readonly property real hairline: Math.max(1, 1.5 / anno.viewScale)
    readonly property real handle: 9 / anno.viewScale
    readonly property real slop: 6 / anno.viewScale

    clip: false

    Repeater {
        model: anno.doc ? anno.doc.annotations : null

        delegate: Item {
            id: entry
            // Not `index` as well: a Repeater over this document's ListModel
            // hands every delegate a zero, so a move wrote itself onto the
            // first annotation instead of its own. Rows are found by uid.
            required property var model

            readonly property var a: model
            readonly property bool selected: anno.doc.selectedId === a.uid
            readonly property bool grabbable: anno.editable && (anno.moving || entry.selected)
            readonly property color ink: (a.color && a.color !== "")
                                         ? a.color : anno.doc.inkColor
            readonly property real stroke: Math.max(1, a.width)
            readonly property bool sizedByContent: a.kind === "text"
            // Where the mark sits by the model. During a move the item is
            // dragged away from this and the model only catches up on
            // release, so anything placed inside the item measures from here
            // and travels with it.
            readonly property real originX: Math.min(a.x, a.x + a.w)
            readonly property real originY: Math.min(a.y, a.y + a.h)

            x: Math.min(a.x, a.x + a.w)
            y: Math.min(a.y, a.y + a.h)
            width: sizedByContent ? Math.max(1, body.implicitWidth) : Math.max(1, Math.abs(a.w))
            height: sizedByContent ? Math.max(1, body.implicitHeight) : Math.max(1, Math.abs(a.h))

            // Keeping the sign of w/h, which says which way it was drawn.
            function commit() {
                anno.doc.updateAnnotation(entry.a.uid, {
                    x: entry.x + (entry.a.w < 0 ? -entry.a.w : 0),
                    y: entry.y + (entry.a.h < 0 ? -entry.a.h : 0)
                });
            }

            // Restores what the drag overwrote.
            function rebind() {
                entry.x = Qt.binding(function () { return Math.min(entry.a.x, entry.a.x + entry.a.w); });
                entry.y = Qt.binding(function () { return Math.min(entry.a.y, entry.a.y + entry.a.h); });
            }

            Loader {
                id: body
                anchors.fill: parent
                sourceComponent: {
                    switch (entry.a.kind) {
                    case "arrow":     return arrowComp;
                    case "ellipse":   return ellipseComp;
                    case "redact":    return redactComp;
                    case "highlight": return highlightComp;
                    case "text":      return textComp;
                    case "step":      return stepComp;
                    // The dim is one layer under every annotation, so a
                    // spotlight has nothing of its own to draw here.
                    case "spotlight": return null;
                    }
                    return boxComp;
                }
            }

            Component {
                id: boxComp
                Rectangle {
                    color: "transparent"
                    border.color: entry.ink
                    border.width: entry.stroke
                    radius: entry.stroke * 1.5
                    antialiasing: true
                }
            }

            Component {
                id: highlightComp
                Rectangle {
                    color: Qt.rgba(entry.ink.r, entry.ink.g, entry.ink.b, 0.3)
                    radius: entry.stroke
                }
            }

            Component {
                id: ellipseComp
                Shape {
                    id: ell
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: entry.ink
                        strokeWidth: entry.stroke
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: ell.width / 2
                            centerY: ell.height / 2
                            radiusX: Math.max(1, ell.width / 2 - entry.stroke / 2)
                            radiusY: Math.max(1, ell.height / 2 - entry.stroke / 2)
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }
                }
            }

            Component {
                id: arrowComp
                Shape {
                    id: arw
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    readonly property real head: Math.max(entry.stroke * 3.2, 10)
                    readonly property var g: Model.arrowShape(entry.a.w, entry.a.h,
                                                              entry.a.style, arw.head)

                    ShapePath {
                        strokeColor: entry.ink
                        strokeWidth: entry.stroke
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        startX: arw.g.sx
                        startY: arw.g.sy
                        // Straight is the same curve with its control point on
                        // the midpoint, so there is only ever one shaft.
                        PathQuad {
                            x: arw.g.ex
                            y: arw.g.ey
                            controlX: arw.g.cx
                            controlY: arw.g.cy
                        }
                    }

                    // A ShapePath cannot be hidden, so a head that is not
                    // wanted is filled with nothing.
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: arw.g.headEnd ? entry.ink : "transparent"
                        startX: arw.g.tipX
                        startY: arw.g.tipY
                        PathLine {
                            x: arw.g.tipX - Math.cos(arw.g.angEnd - 0.42) * arw.head
                            y: arw.g.tipY - Math.sin(arw.g.angEnd - 0.42) * arw.head
                        }
                        PathLine {
                            x: arw.g.tipX - Math.cos(arw.g.angEnd + 0.42) * arw.head
                            y: arw.g.tipY - Math.sin(arw.g.angEnd + 0.42) * arw.head
                        }
                        PathLine { x: arw.g.tipX; y: arw.g.tipY }
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: arw.g.headStart ? entry.ink : "transparent"
                        startX: arw.g.tailX
                        startY: arw.g.tailY
                        PathLine {
                            x: arw.g.tailX - Math.cos(arw.g.angStart - 0.42) * arw.head
                            y: arw.g.tailY - Math.sin(arw.g.angStart - 0.42) * arw.head
                        }
                        PathLine {
                            x: arw.g.tailX - Math.cos(arw.g.angStart + 0.42) * arw.head
                            y: arw.g.tailY - Math.sin(arw.g.angStart + 0.42) * arw.head
                        }
                        PathLine { x: arw.g.tailX; y: arw.g.tailY }
                    }
                }
            }

            // Each block is one sample of the source: destroyed, not blurred.
            Component {
                id: redactComp
                Item {
                    clip: true
                    ShaderEffectSource {
                        anchors.fill: parent
                        visible: anno.pixelSource !== null
                        sourceItem: anno.pixelSource
                        sourceRect: Qt.rect(entry.x, entry.y, entry.width, entry.height)
                        textureSize: Qt.size(
                            Math.max(1, Math.round(entry.width / Math.max(2, entry.a.strength))),
                            Math.max(1, Math.round(entry.height / Math.max(2, entry.a.strength))))
                        smooth: false
                        live: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: anno.pixelSource === null
                        color: "#1a1a1a"
                    }
                }
            }

            Component {
                id: textComp
                Item {
                    implicitWidth: label.implicitWidth + entry.stroke * 2
                    implicitHeight: label.implicitHeight + entry.stroke
                    Text {
                        id: label
                        x: entry.stroke
                        y: entry.stroke / 2
                        readonly property bool placeholder: entry.a.text === ""
                        text: placeholder ? (anno.doc.exporting ? "" : "Type…") : entry.a.text
                        color: entry.ink
                        opacity: placeholder ? 0.55 : 1
                        font.family: Style.font.family
                        font.pixelSize: Math.round(Math.max(12, entry.stroke * 6))
                        font.bold: true
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.55)
                    }
                }
            }

            Component {
                id: stepComp
                Rectangle {
                    radius: width / 2
                    color: entry.ink
                    antialiasing: true
                    Text {
                        anchors.centerIn: parent
                        text: entry.a.index
                        // A white badge had a white number on it.
                        color: Model.textOn(String(entry.ink))
                        font.family: Style.font.family
                        font.bold: true
                        font.pixelSize: Math.round(parent.width * 0.56)
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4 / anno.viewScale
                visible: anno.editable && entry.selected && !anno.doc.exporting
                color: "transparent"
                border.color: Color.accent
                border.width: anno.hairline
                radius: 0
            }

            MouseArea {
                anchors.fill: parent
                id: hold
                anchors.margins: -anno.slop
                enabled: anno.interactive
                hoverEnabled: anno.interactive

                // Whether a press here lands on the mark rather than in the
                // hollow middle of it or off the line of an arrow.
                readonly property bool onMark: Model.hitAnnotation(
                    entry.a,
                    entry.originX - anno.slop + hold.mouseX,
                    entry.originY - anno.slop + hold.mouseY,
                    anno.slop, entry.width, entry.height)

                // The cursor promises only what a press will do: a move where
                // one is on offer, and otherwise whatever the surface
                // underneath would have shown.
                cursorShape: (hold.onMark && entry.grabbable) ? Qt.SizeAllCursor
                           : anno.moving ? Qt.ArrowCursor : Qt.CrossCursor
                drag.target: entry
                drag.threshold: 2

                // A box, an ellipse and an arrow are mostly empty space.
                // Taking the whole bounding box meant whichever was drawn
                // last swallowed every press over what sits inside it, so a
                // press that misses the mark itself is left to the one
                // underneath.
                onPressed: function (e) {
                    var p = mapToItem(anno, e.x, e.y);
                    if (!entry.grabbable
                            || !Model.hitAnnotation(entry.a, p.x, p.y, anno.slop,
                                                    entry.width, entry.height)) {
                        e.accepted = false;
                        return;
                    }
                    anno.doc.selectedId = entry.a.uid;
                }
                // The dim is drawn from the model, so a spotlight has to write
                // its move back as it happens or the hole lags behind the drag.
                onPositionChanged: if (entry.a.kind === "spotlight") entry.commit()
                onReleased: {
                    entry.commit();
                    entry.rebind();
                }
            }

            // Corners to pull it by, or the two ends of an arrow. A fixed
            // count, so a delegate is never rebuilt out from under a drag;
            // a text label is sized by its text and has none.
            Repeater {
                model: 4
                delegate: Rectangle {
                    id: knob
                    required property int index
                    readonly property var spot: Model.resizeHandles(entry.a)[knob.index] || null

                    visible: knob.spot !== null && anno.editable && entry.selected
                             && !anno.doc.exporting
                    x: (knob.spot ? knob.spot.x - entry.originX : 0) - width / 2
                    y: (knob.spot ? knob.spot.y - entry.originY : 0) - height / 2
                    width: anno.handle
                    height: anno.handle
                    color: Color.accent
                    border.width: anno.hairline
                    border.color: Qt.rgba(0, 0, 0, 0.55)

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -anno.slop / 2
                        enabled: knob.visible
                        cursorShape: {
                            var k = knob.spot ? knob.spot.key : "";
                            if (k === "tl" || k === "br") return Qt.SizeFDiagCursor;
                            if (k === "tr" || k === "bl") return Qt.SizeBDiagCursor;
                            return Qt.SizeAllCursor;
                        }

                        onPressed: anno.doc.selectedId = entry.a.uid
                        onPositionChanged: function (e) {
                            if (!pressed || !knob.spot) return;
                            var p = mapToItem(anno, e.x, e.y);
                            // By uid, and through the document, which tells
                            // everything drawn from the model that it moved.
                            anno.doc.updateAnnotation(entry.a.uid,
                                Model.resizeAnnotation(entry.a, knob.spot.key, p.x, p.y));
                        }
                        onReleased: anno.doc.annotationsEdited()
                    }
                }
            }
        }
    }
}
