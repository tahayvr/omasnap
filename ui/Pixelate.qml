import QtQuick

// One sample of the source per block: destroyed, not blurred. Shared by the
// hide tool and by the copy of the shot a magnifier looks through, so a lens
// over a hidden area shows the same blocks and never what is under them.
Item {
    id: pix
    property Item source: null
    property rect area: Qt.rect(0, 0, 0, 0)     // in the source's pixels
    property real block: 14

    clip: true

    ShaderEffectSource {
        anchors.fill: parent
        visible: pix.source !== null
        sourceItem: pix.source
        sourceRect: pix.area
        textureSize: Qt.size(
            Math.max(1, Math.round(pix.area.width / Math.max(2, pix.block))),
            Math.max(1, Math.round(pix.area.height / Math.max(2, pix.block))))
        smooth: false
        live: true
    }
    Rectangle {
        anchors.fill: parent
        visible: pix.source === null
        color: "#1a1a1a"
    }
}
