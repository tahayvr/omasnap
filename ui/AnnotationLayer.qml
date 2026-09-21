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
    property bool interactive: false

    property real viewScale: 1

    clip: false

    Repeater {
        model: anno.doc ? anno.doc.annotations : null

        delegate: Item {
            id: entry
            required property int index
            required property var model

            readonly property var a: model
            readonly property bool selected: anno.doc.selectedId === a.uid
            readonly property color ink: (a.color && a.color !== "")
                                         ? a.color : anno.doc.inkColor
            readonly property real stroke: Math.max(1, a.width)
            readonly property bool sizedByContent: a.kind === "text"

            x: Math.min(a.x, a.x + a.w)
            y: Math.min(a.y, a.y + a.h)
            width: sizedByContent ? Math.max(1, body.implicitWidth) : Math.max(1, Math.abs(a.w))
            height: sizedByContent ? Math.max(1, body.implicitHeight) : Math.max(1, Math.abs(a.h))

            // Keeping the sign of w/h, which says which way it was drawn.
            function commit() {
                var nx = entry.x + (entry.a.w < 0 ? -entry.a.w : 0);
                var ny = entry.y + (entry.a.h < 0 ? -entry.a.h : 0);
                anno.doc.annotations.setProperty(entry.index, "x", nx);
                anno.doc.annotations.setProperty(entry.index, "y", ny);
                anno.doc.annotationsEdited();
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
                        color: "#ffffff"
                        font.family: Style.font.family
                        font.bold: true
                        font.pixelSize: Math.round(parent.width * 0.56)
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4 / anno.viewScale
                visible: anno.interactive && entry.selected && !anno.doc.exporting
                color: "transparent"
                border.color: Color.accent
                border.width: Math.max(1, 1.5 / anno.viewScale)
                radius: 0
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 / anno.viewScale
                enabled: anno.interactive
                cursorShape: Qt.SizeAllCursor
                drag.target: entry
                drag.threshold: 2

                onPressed: anno.doc.selectedId = entry.a.uid
                // The dim is drawn from the model, so a spotlight has to write
                // its move back as it happens or the hole lags behind the drag.
                onPositionChanged: if (entry.a.kind === "spotlight") entry.commit()
                onReleased: {
                    entry.commit();
                    entry.rebind();
                }
            }
        }
    }
}
