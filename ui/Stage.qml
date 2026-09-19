import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Commons
import "../lib/Model.js" as Model

// Laid out at output resolution and displayed scaled; grabToImage() renders it.
Item {
    id: stage

    property var doc: null
    property bool interactive: false
    readonly property var geo: doc.geo

    width: Math.max(1, geo.frameW)
    height: Math.max(1, geo.frameH)

    readonly property bool gradientBg: doc.bgMode === "gradient"
                                       || (doc.bgMode === "auto" && doc.autoPalette.length > 1)

    readonly property color bgA: {
        if (doc.bgMode === "gradient") return Model.gradientByKey(doc.bgGradient).a;
        if (doc.bgMode === "auto" && doc.autoPalette.length > 0) return doc.autoPalette[0];
        if (doc.bgMode === "theme") return Color.background;
        return doc.bgSolid;
    }
    readonly property color bgB: {
        if (doc.bgMode === "gradient") return Model.gradientByKey(doc.bgGradient).b;
        if (doc.bgMode === "auto" && doc.autoPalette.length > 1) return doc.autoPalette[1];
        if (doc.bgMode === "theme") return Qt.darker(Color.background, 1.4);
        return doc.bgSolid;
    }
    readonly property int bgAngle: doc.bgMode === "gradient"
                                   ? Model.gradientByKey(doc.bgGradient).angle
                                   : doc.bgAngle

    readonly property color chromeColor: Qt.darker(Color.background, 1.15)

    Rectangle {
        anchors.fill: parent
        visible: stage.doc.bgMode !== "none" && !stage.gradientBg
        color: stage.bgA
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: stage.doc.bgMode !== "none" && stage.gradientBg
        Rectangle {
            readonly property real diag: Math.sqrt(stage.width * stage.width + stage.height * stage.height)
            width: diag
            height: diag
            anchors.centerIn: parent
            rotation: stage.bgAngle
            gradient: Gradient {
                GradientStop { position: 0.0; color: stage.bgA }
                GradientStop { position: 1.0; color: stage.bgB }
            }
        }
    }

    ClippingRectangle {
        id: card
        x: stage.geo.cardX
        y: stage.geo.cardY
        width: Math.max(1, stage.geo.cardW)
        height: Math.max(1, stage.geo.cardH)
        radius: Math.min(stage.doc.radius / 100 * Math.min(width, height), Math.min(width, height) / 2)
        color: stage.geo.chromeH > 0 ? stage.chromeColor : "transparent"
        visible: false            // drawn by the MultiEffect below

        Item {
            id: chromeBar
            width: parent.width
            height: stage.geo.chromeH
            visible: stage.geo.chromeH > 0

            Rectangle { anchors.fill: parent; color: stage.chromeColor }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: parent.height * 0.45
                spacing: parent.height * 0.26
                Repeater {
                    model: ["#ff5f56", "#ffbd2e", "#27c93f"]
                    Rectangle {
                        required property string modelData
                        width: chromeBar.height * 0.26
                        height: width
                        radius: width / 2
                        color: modelData
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: stage.doc.frame === "titlebar"
                text: stage.doc.frameTitle
                color: Color.foreground
                opacity: 0.75
                font.family: Style.font.family
                font.pixelSize: chromeBar.height * 0.42
                elide: Text.ElideMiddle
                width: parent.width * 0.55
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Image {
            id: shot
            y: stage.geo.chromeH
            width: Math.max(1, stage.geo.shotW)
            height: Math.max(1, stage.geo.shotH)
            source: stage.doc.shotUrl
            cache: true           // shared with the probe and the redaction source
            asynchronous: false
            fillMode: Image.PreserveAspectFit
        }
    }

    MultiEffect {
        source: card
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        autoPaddingEnabled: true
        shadowEnabled: stage.doc.shadow > 0 && stage.doc.bgMode !== "none"
        blurMax: Math.max(32, Math.min(96, Math.round(stage.geo.cardW * 0.03)))
        shadowBlur: Math.max(0, Math.min(1, stage.doc.shadow / 100))
        shadowColor: Qt.rgba(0, 0, 0, stage.doc.shadowOpacity)
        shadowVerticalOffset: stage.doc.shadowY / 100 * Math.max(8, stage.geo.pad)
        shadowHorizontalOffset: 0
    }

    // Unclipped copy for redaction to sample.
    Image {
        id: pixelSource
        source: stage.doc.shotUrl
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
        visible: false
        cache: true
    }

    AnnotationLayer {
        doc: stage.doc
        pixelSource: pixelSource
        interactive: stage.interactive && stage.doc.tool === "select" && !stage.doc.exporting
        viewScale: stage.scale
        x: stage.geo.cardX
        y: stage.geo.cardY + stage.geo.chromeH
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
    }
}
