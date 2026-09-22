import QtQuick
import QtQuick.Effects

// The Postcard wordmark, colorised to whatever foreground it is handed. The
// asset is fixed cyan with an orange shadow, which would otherwise be the one
// thing on screen that ignores the theme.
Item {
    id: wordmark
    property color tint: "#ffffff"
    property real markHeight: 20

    // The asset is 1390x280; the fallback keeps the width sane on the frame
    // before it has loaded and reported its size.
    readonly property real aspect: mark.sourceSize.height > 0
                                   ? mark.sourceSize.width / mark.sourceSize.height
                                   : 1390 / 280

    implicitHeight: wordmark.markHeight
    implicitWidth: Math.round(wordmark.markHeight * wordmark.aspect)

    Image {
        id: mark
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/logo/postcard-logo.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: mark
        colorization: 1
        colorizationColor: wordmark.tint
    }
}
