import QtQuick

// A linear gradient drawn by assets/shaders/ramp.frag, which adds a level of
// noise before the value is quantised. A Rectangle gradient lands in the
// 8-bit framebuffer as it is, and a dark ramp then steps a whole level every
// dozen pixels; grain laid over it afterwards only hides the steps once it
// is itself visible. The shader takes the same five stops as the swatches.
ShaderEffect {
    id: ramp
    property var stops: []          // Model.GRADIENT_STOPS entries of {at, color}
    property real angle: 135        // degrees, clockwise, as Item.rotation

    readonly property size frame: Qt.size(ramp.width, ramp.height)
    readonly property color c0: ramp.stops[0].color
    readonly property color c1: ramp.stops[1].color
    readonly property color c2: ramp.stops[2].color
    readonly property color c3: ramp.stops[3].color
    readonly property color c4: ramp.stops[4].color
    readonly property vector4d pos: Qt.vector4d(ramp.stops[1].at, ramp.stops[2].at,
                                                ramp.stops[3].at, ramp.stops[4].at)

    fragmentShader: Qt.resolvedUrl("../assets/shaders/ramp.frag.qsb")
}
