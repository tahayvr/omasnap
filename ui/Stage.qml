import QtQuick
import QtQuick.Shapes
import qs.Commons
import "../lib/Model.js" as Model

// Laid out at output resolution and displayed scaled; grabToImage() renders it.
Item {
    id: stage

    property var doc: null
    property bool interactive: false
    // What the stage is displayed at, for chrome that has to come out a fixed
    // size on screen. The grab wrapper holds the viewport's fit, so this
    // cannot be read off the stage's own scale.
    property real viewScale: 1
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
                                    ? Model.gradientFor(doc.bgGradient, doc.bgCustomStops, doc.bgCustomAngle) : null
    readonly property bool meshBg: Model.gradientIsMesh(bgPreset)
    // Auto shades one color both ways: the screenshot's dominant color, or a
    // code card's own background, which has no palette to sample.
    readonly property string autoSource: codeKind ? String(doc.codeBg)
                                         : (doc.autoPalette.length > 0 ? String(doc.autoPalette[0]) : "")
    readonly property bool gradientBg: !meshBg
                                       && (doc.bgMode === "gradient"
                                           || (doc.bgMode === "auto" && stage.autoSource !== ""))
    readonly property bool desktopBg: doc.bgMode === "desktop"

    readonly property color bgA: {
        if (doc.bgMode === "auto" && stage.autoSource !== "") return stage.autoSource;
        if (doc.bgMode === "theme") return Color.background;
        return doc.bgSolid;
    }

    // Always Model.GRADIENT_STOPS long, so the stops below can be bound one
    // by one. A Repeater cannot live inside a Gradient, and building the
    // stops at runtime would mean re-creating them on every theme change.
    readonly property var bgStops: {
        if (doc.bgMode === "gradient")
            return Model.gradientStops(stage.bgPreset.stops);
        if (doc.bgMode === "auto" && stage.autoSource !== "")
            return Model.gradientStops(Model.autoGradient(stage.autoSource));
        return Model.gradientStops([String(stage.bgA)]);
    }
    // A multipoint preset has no angle to read, so fall back rather than
    // assigning undefined to an int.
    readonly property int bgAngle: stage.bgPreset && stage.bgPreset.angle !== undefined
                                   ? stage.bgPreset.angle : doc.bgAngle

    // The title bar takes its color from the card underneath it, so a shot
    // and its frame stay in harmony: the code theme's own background, or the
    // screenshot's dominant color as sampled by bin/postcard-palette.
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
    // together from nothing, so it reads as "bigger" rather than "sharper".
    // Everything is measured against shadowRoom, the padding between the
    // card and the edge of the frame: three sigmas plus the drop stay inside
    // it, so the shadow fades out rather than being cut square at the edge.
    readonly property real shadowAmount: Math.max(0, Math.min(1, doc.shadow / 100))
    readonly property real shadowRoom: Math.max(0, doc.geo.pad * unit)
    readonly property real shadowSigma: stage.shadowRoom * (0.08 + 0.17 * stage.shadowAmount)
    readonly property real shadowDrop: stage.shadowRoom * 0.25 * stage.shadowAmount
    readonly property real shadowAlpha: 0.62 * stage.shadowAmount

    readonly property real cardRadiusPx: Math.min(doc.radius / 100 * Math.min(geo.cardW, geo.cardH),
                                                  Math.min(geo.cardW, geo.cardH) / 2)
    readonly property real cardRadius: stage.cardRadiusPx * unit

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
    // Decoded once at its own size: tying sourceSize to the frame made every
    // padding step decode the file again, and the slider stuttered.
    Image {
        anchors.fill: parent
        visible: stage.doc.bgMode === "desktop" && status === Image.Ready
        source: stage.doc.bgMode === "desktop" && stage.doc.desktopBg.length
                ? "file://" + stage.doc.desktopBg : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Ramp {
        anchors.fill: parent
        visible: stage.doc.bgMode !== "none" && !stage.desktopBg && stage.gradientBg
        stops: stage.bgStops
        angle: stage.bgAngle
    }

    Shadow {
        readonly property Item card: stage.codeKind ? codeCard : shotCard
        anchors.fill: parent
        visible: stage.shadowAmount > 0 && stage.shadowRoom > 1
                 && stage.doc.bgMode !== "none"
        box: Qt.rect(card.x, card.y + stage.shadowDrop, card.width, card.height)
        sigma: stage.shadowSigma
        corner: stage.cardRadius
        tint: Qt.rgba(0, 0, 0, stage.shadowAlpha)
    }

    // Screenshot card. The shot is not drawn as an Image inside a clip: every
    // texture round trip — ClippingRectangle, a layer, a MultiEffect mask —
    // resamples it on a fractional scale, where the card is not a whole
    // number of logical pixels. The Shape fills a rounded rectangle straight
    // from the image's own texture, one texel per shot pixel, so a 1x export
    // is the file.
    Rectangle {
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
            topRadius: stage.cardRadius
        }

        Image {
            id: shotTexture
            visible: false
            source: stage.codeKind ? "" : stage.doc.shotUrl
            cache: true           // shared with the probe and the redaction source
            asynchronous: false
        }

        Shape {
            id: shot
            x: stage.geo.inset * stage.unit
            y: (stage.geo.chromeH + stage.geo.inset) * stage.unit
            width: Math.max(1, stage.geo.shotW * stage.unit)
            height: Math.max(1, stage.geo.shotH * stage.unit)
            preferredRendererType: Shape.CurveRenderer
            // Inside an inset the shot sits square within the rounded card;
            // under a title bar only its bottom corners are the card's.
            readonly property real corner: stage.geo.inset > 0 ? 0 : stage.cardRadius
            readonly property real topCorner: stage.geo.chromeH > 0 ? 0 : shot.corner

            ShapePath {
                strokeWidth: -1
                fillItem: shotTexture
                PathRectangle {
                    width: shot.width
                    height: shot.height
                    topLeftRadius: shot.topCorner
                    topRightRadius: shot.topCorner
                    bottomLeftRadius: shot.corner
                    bottomRightRadius: shot.corner
                }
            }
        }
    }

    // Code card: text is inset by its padding, so a rounded Rectangle needs
    // no clipping.
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

    // Over the picture and under the annotations: an arrow drawn on a dimmed
    // area stays as bright as one drawn on the spotlight.
    Spotlight {
        doc: stage.doc
        holeOffset: stage.geo.inset
        topRadius: stage.geo.chromeH > 0 ? 0 : stage.cardRadiusPx
        bottomRadius: stage.cardRadiusPx
        x: stage.geo.cardX * stage.unit
        y: (stage.geo.cardY + stage.geo.chromeH) * stage.unit
        width: Math.max(1, stage.geo.cardW)
        height: Math.max(1, stage.geo.cardH - stage.geo.chromeH)
        transformOrigin: Item.TopLeft
        scale: stage.unit
    }

    // In shot pixels, scaled into place.
    AnnotationLayer {
        doc: stage.doc
        pixelSource: stage.codeKind ? codeSource : pixelSource
        interactive: stage.interactive && !stage.doc.exporting
        viewScale: stage.viewScale * stage.unit
        x: (stage.geo.cardX + stage.geo.inset) * stage.unit
        y: (stage.geo.cardY + stage.geo.chromeH + stage.geo.inset) * stage.unit
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
        transformOrigin: Item.TopLeft
        scale: stage.unit
    }

    // Over everything, since it is about the picture rather than part of it.
    CropOverlay {
        doc: stage.doc
        viewScale: stage.viewScale * stage.unit
        x: (stage.geo.cardX + stage.geo.inset) * stage.unit
        y: (stage.geo.cardY + stage.geo.chromeH + stage.geo.inset) * stage.unit
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)
        transformOrigin: Item.TopLeft
        scale: stage.unit
    }
}
