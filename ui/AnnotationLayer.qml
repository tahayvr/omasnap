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
    // The shot with hidden areas already pixelated, for a magnifier to show.
    property Item magnifySource: null
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
            readonly property bool selected: anno.doc.selectedIds.indexOf(a.uid) !== -1
            // Handles are for one mark at a time.
            readonly property bool alone: entry.selected && anno.doc.selectedIds.length === 1
            // Carried along while another selected mark is dragged.
            readonly property point follow: (entry.selected && anno.doc.groupLeader !== ""
                                             && anno.doc.groupLeader !== a.uid)
                                            ? anno.doc.groupShift : Qt.point(0, 0)
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

            x: Math.min(a.x, a.x + a.w) + entry.follow.x
            y: Math.min(a.y, a.y + a.h) + entry.follow.y
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
                entry.x = Qt.binding(function () { return Math.min(entry.a.x, entry.a.x + entry.a.w) + entry.follow.x; });
                entry.y = Qt.binding(function () { return Math.min(entry.a.y, entry.a.y + entry.a.h) + entry.follow.y; });
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
                    case "magnify":   return magnifyComp;
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

            Component {
                id: redactComp
                Pixelate {
                    source: anno.pixelSource
                    area: Qt.rect(entry.x, entry.y, entry.width, entry.height)
                    block: entry.a.strength
                }
            }

            // The lens is this item's box; the area it shows and the line to it
            // are drawn outside it. Measured from where the lens is now rather
            // than where the model has it, so while the lens is dragged the
            // area stays put and the line follows.
            Component {
                id: magnifyComp
                Item {
                    id: mag
                    readonly property real lensR: entry.width / 2
                    readonly property real power: Model.magnifyZoom(entry.a.zoom)
                    readonly property real srcR: mag.lensR / mag.power
                    readonly property real srcX: entry.a.sx - entry.x
                    readonly property real srcY: entry.a.sy - entry.y
                    readonly property var link: Model.magnifyLink(mag.lensR, mag.lensR, mag.lensR,
                                                                  mag.srcX, mag.srcY, mag.srcR)

                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        // A ShapePath cannot be hidden, so a line that is not
                        // wanted is stroked with nothing.
                        ShapePath {
                            strokeColor: mag.link ? entry.ink : "transparent"
                            strokeWidth: entry.stroke
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            startX: mag.link ? mag.link.x1 : 0
                            startY: mag.link ? mag.link.y1 : 0
                            PathLine {
                                x: mag.link ? mag.link.x2 : 0
                                y: mag.link ? mag.link.y2 : 0
                            }
                        }
                        ShapePath {
                            strokeColor: entry.ink
                            strokeWidth: entry.stroke
                            fillColor: "transparent"
                            PathAngleArc {
                                centerX: mag.srcX
                                centerY: mag.srcY
                                radiusX: Math.max(1, mag.srcR)
                                radiusY: Math.max(1, mag.srcR)
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                    }

                    // One texel per shot pixel, scaled up unsmoothed: each
                    // pixel becomes a clean block rather than a blur.
                    ShaderEffectSource {
                        id: lensTexture
                        visible: false
                        width: entry.width
                        height: entry.height
                        sourceItem: anno.magnifySource
                        sourceRect: Qt.rect(entry.a.sx - mag.srcR, entry.a.sy - mag.srcR,
                                            mag.srcR * 2, mag.srcR * 2)
                        textureSize: Qt.size(Math.max(1, Math.round(mag.srcR * 2)),
                                             Math.max(1, Math.round(mag.srcR * 2)))
                        smooth: false
                        live: true
                    }

                    // assets/shaders/lens.frag stretches the texture over the
                    // lens and cuts the circle. A Shape filled with it mapped
                    // the texture at a scale that followed the layer's
                    // transform, and a layer mask would resample it.
                    ShaderEffect {
                        anchors.fill: parent
                        visible: anno.magnifySource !== null
                        property variant source: lensTexture
                        // About a pixel and a half of fade at the rim.
                        property real edge: Math.min(0.5, 1.5 / Math.max(1, mag.lensR))
                        fragmentShader: Qt.resolvedUrl("../assets/shaders/lens.frag.qsb")
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: entry.ink
                            strokeWidth: entry.stroke
                            fillColor: anno.magnifySource ? "transparent" : "#1a1a1a"
                            PathAngleArc {
                                centerX: mag.lensR
                                centerY: mag.lensR
                                radiusX: Math.max(1, mag.lensR - entry.stroke / 2)
                                radiusY: Math.max(1, mag.lensR - entry.stroke / 2)
                                startAngle: 0
                                sweepAngle: 360
                            }
                        }
                    }
                }
            }

            Component {
                id: textComp
                Item {
                    readonly property real pad: label.font.pixelSize / 6
                    implicitWidth: label.implicitWidth + pad * 2
                    implicitHeight: label.implicitHeight + pad
                    Text {
                        id: label
                        x: parent.pad
                        y: parent.pad / 2
                        readonly property bool placeholder: entry.a.text === ""
                        text: placeholder ? (anno.doc.exporting ? "" : "Type…") : entry.a.text
                        color: entry.ink
                        opacity: placeholder ? 0.55 : 1
                        font.pixelSize: Math.round(Model.textSize(entry.a))
                        font.family: Model.textFamily(entry.a.font)
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
                // Shift-clicking adds a mark to the selection or takes it out,
                // and does not move anything.
                property bool toggling: false
                drag.target: hold.toggling ? null : entry
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
                    hold.toggling = anno.moving && (e.modifiers & Qt.ShiftModifier);
                    if (hold.toggling) {
                        anno.doc.toggleSelected(entry.a.uid);
                        return;
                    }
                    // Taking hold of one of a group moves the group.
                    if (entry.selected) anno.doc.selectMany(anno.doc.selectedIds, entry.a.uid);
                    else anno.doc.selectedId = entry.a.uid;
                    if (anno.doc.selectedIds.length > 1) anno.doc.groupLeader = entry.a.uid;
                }
                // The dim is drawn from the model, so a spotlight has to write
                // its move back as it happens or the hole lags behind the drag.
                onPositionChanged: {
                    if (hold.toggling) return;
                    if (anno.doc.groupLeader === entry.a.uid)
                        anno.doc.groupShift = Qt.point(entry.x - entry.originX, entry.y - entry.originY);
                    if (entry.a.kind === "spotlight") entry.commit();
                }
                onReleased: {
                    if (hold.toggling) { hold.toggling = false; return; }
                    if (anno.doc.groupLeader === entry.a.uid) {
                        anno.doc.moveSelection(entry.x - entry.originX, entry.y - entry.originY, entry.a.uid);
                        anno.doc.groupLeader = "";
                        anno.doc.groupShift = Qt.point(0, 0);
                    }
                    entry.commit();
                    entry.rebind();
                }
            }

            // A magnifier's area moves on its own, the lens staying where it is.
            MouseArea {
                id: sourceGrab
                readonly property real r: entry.a.kind === "magnify"
                                          ? Model.magnifySource(entry.a).r : 0
                visible: entry.a.kind === "magnify"
                enabled: visible && entry.grabbable
                x: entry.a.sx - entry.x - sourceGrab.r - anno.slop
                y: entry.a.sy - entry.y - sourceGrab.r - anno.slop
                width: (sourceGrab.r + anno.slop) * 2
                height: (sourceGrab.r + anno.slop) * 2
                cursorShape: Qt.SizeAllCursor
                property real offX: 0
                property real offY: 0

                onPressed: function (e) {
                    var p = mapToItem(anno, e.x, e.y);
                    sourceGrab.offX = p.x - entry.a.sx;
                    sourceGrab.offY = p.y - entry.a.sy;
                    anno.doc.selectedId = entry.a.uid;
                }
                onPositionChanged: function (e) {
                    if (!pressed) return;
                    var p = mapToItem(anno, e.x, e.y);
                    anno.doc.updateAnnotation(entry.a.uid, {
                        sx: Math.round(Model.clamp(p.x - sourceGrab.offX, 0, anno.doc.shotWidth)),
                        sy: Math.round(Model.clamp(p.y - sourceGrab.offY, 0, anno.doc.shotHeight))
                    });
                }
                onReleased: anno.doc.annotationsEdited()
            }

            // Corners and sides to pull it by, or the two ends of an arrow.
            // A fixed count, so a delegate is never rebuilt out from under a
            // drag. A text label's corners are where its text ends, which
            // only this delegate can measure.
            Repeater {
                model: 8
                delegate: Rectangle {
                    id: knob
                    required property int index
                    readonly property var spot: Model.resizeHandles(entry.a, entry.width, entry.height)[knob.index] || null
                    readonly property bool side: knob.spot !== null && Model.isSideHandle(knob.spot.key)
                    readonly property bool across: knob.side && (knob.spot.key === "t" || knob.spot.key === "b")

                    // A side too short to hold a bar clear of its corners
                    // is left to them.
                    visible: knob.spot !== null && anno.editable && entry.alone
                             && !anno.doc.exporting
                             && (!knob.side || Math.abs(knob.across ? entry.a.w : entry.a.h) > anno.handle * 5)
                    x: (knob.spot ? knob.spot.x - entry.originX : 0) - width / 2
                    y: (knob.spot ? knob.spot.y - entry.originY : 0) - height / 2
                    width: !knob.side ? anno.handle : knob.across ? anno.handle * 2.4 : anno.handle * 0.7
                    height: !knob.side ? anno.handle : knob.across ? anno.handle * 0.7 : anno.handle * 2.4
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
                            if (k === "t" || k === "b") return Qt.SizeVerCursor;
                            if (k === "l" || k === "r") return Qt.SizeHorCursor;
                            return Qt.SizeAllCursor;
                        }

                        onPressed: anno.doc.selectedId = entry.a.uid
                        onPositionChanged: function (e) {
                            if (!pressed || !knob.spot) return;
                            var p = mapToItem(anno, e.x, e.y);
                            // By uid, and through the document, which tells
                            // everything drawn from the model that it moved.
                            anno.doc.updateAnnotation(entry.a.uid,
                                Model.resizeAnnotation(entry.a, knob.spot.key, p.x, p.y,
                                                       entry.width, entry.height));
                        }
                        onReleased: {
                            // The next label starts at the size this one was left at.
                            if (entry.a.kind === "text") anno.doc.textSize = entry.a.fontSize;
                            anno.doc.annotationsEdited();
                        }
                    }
                }
            }
        }
    }
}
