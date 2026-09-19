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
    readonly property bool codeKind: doc.kind === "code"

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
    readonly property real cardRadius: Math.min(doc.radius / 100 * Math.min(geo.cardW, geo.cardH),
                                                Math.min(geo.cardW, geo.cardH) / 2)

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

    // Screenshot card: the image needs clipping to the rounded corners.
    ClippingRectangle {
        id: shotCard
        x: stage.geo.cardX
        y: stage.geo.cardY
        width: Math.max(1, stage.geo.cardW)
        height: Math.max(1, stage.geo.cardH)
        radius: stage.cardRadius
        color: stage.geo.chromeH > 0 ? stage.chromeColor : "transparent"
        visible: false            // drawn by the MultiEffect below

        Chrome {
            doc: stage.doc
            height: stage.geo.chromeH
            color: stage.chromeColor
        }

        Image {
            visible: !stage.codeKind
            y: stage.geo.chromeH
            width: Math.max(1, stage.geo.shotW)
            height: Math.max(1, stage.geo.shotH)
            source: stage.codeKind ? "" : stage.doc.shotUrl
            cache: true           // shared with the probe and the redaction source
            asynchronous: false
            fillMode: Image.PreserveAspectFit
        }
    }

    MultiEffect {
        readonly property Item card: stage.codeKind ? codeCard : shotCard
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

    // Code card: text is inset by its padding, so a rounded Rectangle needs
    // no clipping. It stays visible and sits over the effect above, which
    // then only contributes the shadow: children of a hidden effect source
    // did not render inside the shell.
    Rectangle {
        id: codeCard
        visible: stage.codeKind
        x: stage.geo.cardX
        y: stage.geo.cardY
        width: Math.max(1, stage.geo.cardW)
        height: Math.max(1, stage.geo.cardH)
        radius: stage.cardRadius
        color: stage.doc.codeBg

        Chrome {
            doc: stage.doc
            height: stage.geo.chromeH
            color: stage.chromeColor
            topRadius: stage.cardRadius
        }

        CodeBlock {
            id: codeBlock
            doc: stage.doc
            y: stage.geo.chromeH
            // The card takes its size from the text, not the other way round.
            onMeasured: function (w, h) {
                if (!stage.codeKind) return;
                stage.doc.shotWidth = w;
                stage.doc.shotHeight = h;
            }
        }
    }

    // Unclipped copies for redaction to sample.
    Image {
        id: pixelSource
        source: stage.codeKind ? "" : stage.doc.shotUrl
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
        visible: false
        cache: true
    }
    Rectangle {
        id: codeSource
        visible: false
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
        color: stage.doc.codeBg
        CodeBlock { doc: stage.doc }
    }

    AnnotationLayer {
        doc: stage.doc
        pixelSource: stage.codeKind ? codeSource : pixelSource
        interactive: stage.interactive && stage.doc.tool === "select" && !stage.doc.exporting
        viewScale: stage.scale
        x: stage.geo.cardX
        y: stage.geo.cardY + stage.geo.chromeH
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
    }
}
