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

    readonly property var bgPreset: doc.bgMode === "gradient"
                                    ? Model.gradientByKey(doc.bgGradient) : null
    readonly property bool meshBg: Model.gradientIsMesh(bgPreset)
    readonly property bool gradientBg: !meshBg
                                       && (doc.bgMode === "gradient"
                                           || (doc.bgMode === "auto" && doc.autoPalette.length > 0))
    readonly property bool desktopBg: doc.bgMode === "desktop"

    readonly property color bgA: {
        if (doc.bgMode === "auto" && doc.autoPalette.length > 0) return doc.autoPalette[0];
        if (doc.bgMode === "theme") return Color.background;
        return doc.bgSolid;
    }

    // Always Model.GRADIENT_STOPS long, so the stops below can be bound one
    // by one. A Repeater cannot live inside a Gradient, and building the
    // stops at runtime would mean re-creating them on every theme change.
    readonly property var bgStops: {
        if (doc.bgMode === "gradient")
            return Model.gradientStops(Model.gradientByKey(doc.bgGradient).stops);
        if (doc.bgMode === "auto" && doc.autoPalette.length > 0)
            return Model.gradientStops(Model.autoGradient(String(doc.autoPalette[0])));
        return Model.gradientStops([String(stage.bgA)]);
    }
    // A multipoint preset has no angle to read, so fall back rather than
    // assigning undefined to an int.
    readonly property int bgAngle: stage.bgPreset && stage.bgPreset.angle !== undefined
                                   ? stage.bgPreset.angle : doc.bgAngle

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
    // One slider drives the whole shadow. Spread, drop and opacity all rise
    // together from nothing, so it reads as "bigger" rather than "sharper";
    // the old control fed the slider straight into the blur, which made 1 a
    // hard shadow and 100 a soft one.
    readonly property real shadowAmount: Math.max(0, Math.min(1, doc.shadow / 100))

    // The gap between the card and the edge of the frame. The shadow has to
    // finish inside it; with no padding there is nowhere for one to fall.
    readonly property real shadowRoom: Math.max(0, doc.geo.pad * unit)
    readonly property real cardRadius: Math.min(doc.radius / 100 * Math.min(geo.cardW, geo.cardH),
                                                Math.min(geo.cardW, geo.cardH) / 2) * unit

    Rectangle {
        anchors.fill: parent
        visible: stage.doc.bgMode !== "none" && !stage.desktopBg && !stage.meshBg
                 && !stage.gradientBg
        color: stage.bgA
    }

    // A multipoint preset: colors scattered over the frame instead of a ramp.
    MeshGradient {
        anchors.fill: parent
        visible: stage.meshBg
        base: stage.meshBg ? stage.bgPreset.base : "transparent"
        points: stage.meshBg ? Model.meshPoints(stage.bgPreset) : []
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
                GradientStop { position: stage.bgStops[0].at; color: stage.bgStops[0].color }
                GradientStop { position: stage.bgStops[1].at; color: stage.bgStops[1].color }
                GradientStop { position: stage.bgStops[2].at; color: stage.bgStops[2].color }
                GradientStop { position: stage.bgStops[3].at; color: stage.bgStops[3].color }
                GradientStop { position: stage.bgStops[4].at; color: stage.bgStops[4].color }
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
        shadowEnabled: stage.shadowAmount > 0 && stage.shadowRoom > 1
                       && stage.doc.bgMode !== "none"
        // blurMultiplier buys radius at the cost of sampling quality, and it
        // showed as stepping down the falloff, so the radius comes from
        // blurMax alone. Everything is measured against shadowRoom: reach and
        // drop together stay inside the padding, so the shadow fades out
        // rather than running into the edge of the frame and being cut square.
        blurMax: Math.round(Math.max(8, Math.min(160, stage.shadowRoom * 1.15)))
        blurMultiplier: 0
        shadowBlur: 0.45 + 0.55 * stage.shadowAmount
        shadowColor: Qt.rgba(0, 0, 0, 0.38 * stage.shadowAmount)
        shadowVerticalOffset: stage.shadowRoom * 0.30 * stage.shadowAmount
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
