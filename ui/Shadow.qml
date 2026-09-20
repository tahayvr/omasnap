import QtQuick

// The card's drop shadow, drawn by assets/shaders/shadow.frag over the
// background and under the card: a closed-form Gaussian blur of the rounded
// box, dithered before it is quantised, so it never rings or steps however
// large the padding lets it grow.
ShaderEffect {
    id: shadow
    property rect box: Qt.rect(0, 0, 1, 1)   // in item pixels, offset included
    property real sigma: 8
    property real corner: 0
    property color tint: Qt.rgba(0, 0, 0, 0.5)

    readonly property size frame: Qt.size(shadow.width, shadow.height)

    fragmentShader: Qt.resolvedUrl("../assets/shaders/shadow.frag.qsb")
}
