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

    // Geometry is in shot pixels; the stage is laid out in shot pixels divided
    // by the window's device pixel ratio. Effect textures (clipping, shadow)
    // are allocated at item size times that ratio, so this makes them exactly
    // one texel per shot pixel and a 1x export pixel-exact. It also means a
    // stage scale of 1 shows the shot life-size.
    readonly property real dpr: {
        var w = stage.Window.window;
        return w && w.devicePixelRatio > 0 ? w.devicePixelRatio : 1;
    }
    readonly property real unit: 1 / dpr

    width: Math.max(1, geo.frameW * unit)
    height: Math.max(1, geo.frameH * unit)

    readonly property bool gradientBg: doc.bgMode === "gradient"
                                       || (doc.bgMode === "auto" && doc.autoPalette.length > 1)
    readonly property bool desktopBg: doc.bgMode === "desktop"

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

    // The title bar takes its color from the card underneath it, so a shot
    // and its frame stay in harmony: the code theme's own background, or the
    // screenshot's dominant color as sampled by bin/snap-palette.
    readonly property string chromeSource: {
        if (codeKind) return String(doc.codeBg);
        return doc.shotPalette.length > 0 ? String(doc.shotPalette[0]) : "";
    }
    readonly property color chromeColor: {
        var tint = Model.chromeTint(stage.chromeSource);
        return tint ? tint : Qt.darker(Color.background, 1.15);
    }
    readonly property color chromeTextColor: Model.textOn(Model.chromeTint(stage.chromeSource))

    // What an inset extends outwards: the shot's own edge color, so the
    // extension continues the image instead of butting up against it. The
    // overall dominant color is the fallback, and a code card just carries
    // on its own background.
    readonly property color insetColor: {
        if (codeKind) return doc.codeBg;
        if (doc.shotEdge.length) return doc.shotEdge;
        if (doc.shotPalette.length > 0) return doc.shotPalette[0];
        return stage.chromeColor;
    }
    readonly property real cardRadius: Math.min(doc.radius / 100 * Math.min(geo.cardW, geo.cardH),
                                                Math.min(geo.cardW, geo.cardH) / 2) * unit

    Rectangle {
        anchors.fill: parent
        visible: stage.doc.bgMode !== "none" && !stage.desktopBg && !stage.gradientBg
        color: stage.bgA
    }

    // The desktop wallpaper, cropped to the frame the way a compositor would.
    Image {
        anchors.fill: parent
        visible: stage.doc.bgMode === "desktop" && status === Image.Ready
        source: stage.doc.bgMode === "desktop" && stage.doc.desktopBg.length
                ? "file://" + stage.doc.desktopBg : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        sourceSize.width: Math.max(1, Math.round(stage.width * stage.dpr))
        sourceSize.height: Math.max(1, Math.round(stage.height * stage.dpr))
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: stage.doc.bgMode !== "none" && !stage.desktopBg && stage.gradientBg
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

    MultiEffect {
        readonly property Item card: stage.codeKind ? codeCard : shotCard
        source: card
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        autoPaddingEnabled: true
        shadowEnabled: stage.doc.shadow > 0 && stage.doc.bgMode !== "none"
        blurMax: Math.max(32, Math.min(96, Math.round(stage.geo.cardW * stage.unit * 0.03)))
        shadowBlur: Math.max(0, Math.min(1, stage.doc.shadow / 100))
        shadowColor: Qt.rgba(0, 0, 0, stage.doc.shadowOpacity)
        shadowVerticalOffset: stage.doc.shadowY / 100 * Math.max(8, stage.geo.pad) * stage.unit
        shadowHorizontalOffset: 0
    }

    // Screenshot card: the image needs clipping to the rounded corners. Like
    // the code card it stays visible over its effect, which then only adds
    // the shadow: MultiEffect's auto padding shifts its copy of the source by
    // a fraction of a pixel, which would resample the screenshot.
    ClippingRectangle {
        id: shotCard
        x: stage.geo.cardX * stage.unit
        y: stage.geo.cardY * stage.unit
        width: Math.max(1, stage.geo.cardW * stage.unit)
        height: Math.max(1, stage.geo.cardH * stage.unit)
        radius: stage.cardRadius
        color: stage.geo.inset > 0 ? stage.insetColor
             : (stage.geo.chromeH > 0 ? stage.chromeColor : "transparent")
        visible: !stage.codeKind

        Chrome {
            doc: stage.doc
            height: stage.geo.chromeH * stage.unit
            color: stage.chromeColor
            textColor: stage.chromeTextColor
        }

        Image {
            visible: !stage.codeKind
            x: stage.geo.inset * stage.unit
            y: (stage.geo.chromeH + stage.geo.inset) * stage.unit
            width: Math.max(1, stage.geo.shotW * stage.unit)
            height: Math.max(1, stage.geo.shotH * stage.unit)
            source: stage.codeKind ? "" : stage.doc.shotUrl
            cache: true           // shared with the probe and the redaction source
            asynchronous: false
            fillMode: Image.PreserveAspectFit
        }
    }

    // Code card: text is inset by its padding, so a rounded Rectangle needs
    // no clipping. It stays visible and sits over the effect above, which
    // then only contributes the shadow: children of a hidden effect source
    // did not render inside the shell.
    Rectangle {
        id: codeCard
        visible: stage.codeKind
        x: stage.geo.cardX * stage.unit
        y: stage.geo.cardY * stage.unit
        width: Math.max(1, stage.geo.cardW * stage.unit)
        height: Math.max(1, stage.geo.cardH * stage.unit)
        radius: stage.cardRadius
        color: stage.doc.codeBg

        Chrome {
            doc: stage.doc
            height: stage.geo.chromeH * stage.unit
            color: stage.chromeColor
            textColor: stage.chromeTextColor
            topRadius: stage.cardRadius
        }

        // Measured in shot pixels, drawn scaled; text is rasterised at the
        // final scale so it stays crisp.
        CodeBlock {
            id: codeBlock
            doc: stage.doc
            x: stage.geo.inset * stage.unit
            y: (stage.geo.chromeH + stage.geo.inset) * stage.unit
            transformOrigin: Item.TopLeft
            scale: stage.unit
        }

        // The card takes its size from the text, not the other way round.
        // Bound rather than pushed on a change signal: loadCode zeroes the
        // document's size, and re-rendering the same snippet leaves the
        // block's natural size untouched, so a signal would never fire and
        // the card stayed empty.
        Binding {
            target: stage.doc
            property: "shotWidth"
            value: codeBlock.naturalW
            when: stage.codeKind
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: stage.doc
            property: "shotHeight"
            value: codeBlock.naturalH
            when: stage.codeKind
            restoreMode: Binding.RestoreNone
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

    // In shot pixels, scaled into place.
    AnnotationLayer {
        doc: stage.doc
        pixelSource: stage.codeKind ? codeSource : pixelSource
        interactive: stage.interactive && stage.doc.tool === "select" && !stage.doc.exporting
        viewScale: stage.scale * stage.unit
        x: (stage.geo.cardX + stage.geo.inset) * stage.unit
        y: (stage.geo.cardY + stage.geo.chromeH + stage.geo.inset) * stage.unit
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
        transformOrigin: Item.TopLeft
        scale: stage.unit
    }
}
