import QtQuick
import QtQuick.Shapes
import "../lib/Model.js" as Model

// The picture dimmed everywhere a spotlight is not. It covers the card below
// the title bar rather than the screenshot alone, so an inset band dims with
// the picture it extends; the padding and the background never do.
Item {
    id: spot

    property var doc: null
    property real holeOffset: 0            // the inset, between card and shot
    property real topRadius: 0
    property real bottomRadius: 0

    readonly property real amount: doc ? Model.clamp(doc.spotDim / 100, 0, 1) : 0
    visible: doc !== null && doc.spotlightCount > 0 && amount > 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: Qt.rgba(0, 0, 0, spot.amount)
            strokeWidth: -1
            PathSvg {
                path: {
                    if (!spot.doc)
                        return "";
                    // Read for the dependency alone: a ListModel notifies
                    // nothing a binding can follow, so every edit bumps this.
                    spot.doc.annotationRevision;
                    return Model.spotlightPath(spot.width, spot.height,
                                               spot.topRadius, spot.bottomRadius,
                                               Model.spotlightHoles(spot.doc.annotations,
                                                                    spot.holeOffset,
                                                                    spot.doc.spotShape));
                }
            }
        }
    }
}
