import QtQuick
import QtQuick.Shapes

// A multipoint (mesh) gradient. A linear gradient only varies along one axis;
// this places colors anywhere in the frame and lets them fade into each other
// in two, which is what gives the soft organic wash. Each point is a radial
// fill from its color out to the same color at zero alpha, stacked over a base.
Item {
    id: mesh
    property color base: "#000000"
    property var points: []     // [{ x, y, r, color }], all fractions of the frame

    Rectangle {
        anchors.fill: parent
        color: mesh.base
    }

    Repeater {
        model: mesh.points

        // Qt has no radial fill for a Rectangle, so every point is a Shape
        // covering the whole frame; the curve renderer is the one that draws
        // these gradients smoothly. Everything reads off the delegate rather
        // than the outer id, which the linter cannot see through.
        Shape {
            id: blob
            required property var modelData
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property color tint: blob.modelData.color
            readonly property real span: Math.max(blob.width, blob.height)

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: blob.modelData.x * blob.width
                    centerY: blob.modelData.y * blob.height
                    centerRadius: Math.max(1, blob.modelData.r * blob.span)
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0; color: blob.tint }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0)
                    }
                }
                startX: 0
                startY: 0
                PathLine { x: blob.width; y: 0 }
                PathLine { x: blob.width; y: blob.height }
                PathLine { x: 0; y: blob.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
