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

    // The same on every card, from the smallest, so no card is rounder.
    readonly property real cardRadiusPx: {
        var side = Math.min(geo.cardW, geo.cardH);
        stage.cards.forEach(function (c) { side = Math.min(side, c.w, c.h); });
        return Math.min(doc.radius / 100 * side, side / 2);
    }
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

    // The cards, one per shot, in shot pixels: where each sits on the sheet
    // (Model.sheetLayout), plus the room its inset and title bar take. A
    // picture not yet laid out, or a code card, is one card the size of the
    // picture.
    readonly property var cards: {
        var inset = stage.geo.inset, chrome = stage.geo.chromeH;
        var items = !stage.codeKind && doc.sheet && doc.sheet.items.length
                  ? doc.sheet.items : [{ id: "", x: 0, y: 0, w: stage.geo.shotW, h: stage.geo.shotH }];
        return items.map(function (it) {
            var n = Model.slotById(doc.slots, it.id);
            var slot = n >= 0 ? doc.slots[n] : null;
            // The first card's title bar is tinted from the shot's colors, as
            // a single shot's is; the others take theirs from their own edge,
            // so a green shot does not wear the first one's red.
            var tint = n > 0 && slot && slot.edge ? Model.chromeTint(slot.edge) : "";
            return { x: stage.geo.cardX + it.x, y: stage.geo.cardY + it.y,
                     chrome: tint ? tint : String(stage.chromeColor),
                     chromeText: tint ? Model.textOn(tint) : String(stage.chromeTextColor),
                     w: it.w + inset * 2, h: it.h + inset * 2 + chrome,
                     sx: it.x, sy: it.y, sw: it.w, sh: it.h,
                     title: doc.slots.length > 1 && slot ? slot.name : doc.frameTitle,
                     edge: slot && slot.edge ? slot.edge : "" };
        });
    }

    Repeater {
        model: stage.cards
        Shadow {
            required property var modelData
            anchors.fill: parent
            visible: stage.shadowAmount > 0 && stage.shadowRoom > 1
                     && stage.doc.bgMode !== "none"
            box: Qt.rect(modelData.x * stage.unit, (modelData.y + stage.shadowDrop / stage.unit) * stage.unit,
                         modelData.w * stage.unit, modelData.h * stage.unit)
            sigma: stage.shadowSigma
            corner: stage.cardRadius
            tint: Qt.rgba(0, 0, 0, stage.shadowAlpha)
        }
    }

    // What every card is filled from: the picture, or the sheet of shots.
    Image {
        id: shotTexture
        visible: false
        source: stage.codeKind ? "" : stage.doc.shotUrl
        cache: true           // shared with the probe and the redaction source
        asynchronous: false
    }

    // Screenshot cards. A shot is not drawn as an Image inside a clip: every
    // texture round trip — ClippingRectangle, a layer, a MultiEffect mask —
    // resamples it on a fractional scale, where the card is not a whole
    // number of logical pixels. The Shape fills a rounded rectangle straight
    // from the picture's own texture, one texel per shot pixel, so a 1x
    // export is the file. With several shots each card takes its own part of
    // the sheet, by moving the fill rather than the shape.
    Repeater {
        model: stage.codeKind ? [] : stage.cards
        Rectangle {
            id: shotCard
            required property var modelData
            x: modelData.x * stage.unit
            y: modelData.y * stage.unit
            width: Math.max(1, modelData.w * stage.unit)
            height: Math.max(1, modelData.h * stage.unit)
            radius: stage.cardRadius
            color: stage.geo.inset > 0 ? (modelData.edge !== "" ? modelData.edge : stage.insetColor)
                 : (stage.geo.chromeH > 0 ? modelData.chrome : "transparent")

            Chrome {
                title: shotCard.modelData.title
                height: stage.geo.chromeH * stage.unit
                color: shotCard.modelData.chrome
                textColor: shotCard.modelData.chromeText
                topRadius: stage.cardRadius
            }

            Shape {
                id: shot
                x: stage.geo.inset * stage.unit
                y: (stage.geo.chromeH + stage.geo.inset) * stage.unit
                width: Math.max(1, shotCard.modelData.sw * stage.unit)
                height: Math.max(1, shotCard.modelData.sh * stage.unit)
                preferredRendererType: Shape.CurveRenderer
                // Inside an inset the shot sits square within the rounded card;
                // under a title bar only its bottom corners are the card's.
                readonly property real corner: stage.geo.inset > 0 ? 0 : stage.cardRadius
                readonly property real topCorner: stage.geo.chromeH > 0 ? 0 : shot.corner

                ShapePath {
                    strokeWidth: -1
                    fillItem: shotTexture
                    fillTransform: PlanarTransform.fromTranslate(-shotCard.modelData.sx * stage.unit,
                                                                 -shotCard.modelData.sy * stage.unit)
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
    }

    Shadow {
        anchors.fill: parent
        visible: stage.codeKind && stage.shadowAmount > 0 && stage.shadowRoom > 1
                 && stage.doc.bgMode !== "none"
        box: Qt.rect(codeCard.x, codeCard.y + stage.shadowDrop, codeCard.width, codeCard.height)
        sigma: stage.shadowSigma
        corner: stage.cardRadius
        tint: Qt.rgba(0, 0, 0, stage.shadowAlpha)
    }

    // The watermark, under the card's bottom-right corner (Model.watermarkBox).
    readonly property var markBox: Model.watermarkBox(stage.geo, doc.watermarkSize)
    // What it sits on, for light or dark ink: the card when tucked inside
    // it, the background otherwise.
    readonly property var markInk: {
        if (stage.markBox.inside)
            return Model.watermarkInk(stage.codeKind ? [String(doc.codeBg)]
                                      : doc.shotPalette.length ? [String(doc.shotPalette[0])] : []);
        if (doc.bgMode === "none" || stage.desktopBg) return null;
        if (stage.meshBg) return Model.watermarkInk([stage.bgPreset.base]);
        return Model.watermarkInk(stage.bgStops.map(function (s) { return String(s.color); }));
    }

    Row {
        id: watermark
        z: 3
        visible: doc.hasWatermark
        anchors.right: parent.right
        anchors.rightMargin: (stage.geo.frameW - stage.markBox.right) * stage.unit
        y: stage.markBox.top * stage.unit
        height: stage.markBox.rowH * stage.unit
        spacing: stage.markBox.size * 0.45 * stage.unit
        opacity: 0.9

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: doc.watermarkLogo !== "" && status === Image.Ready
            source: doc.watermarkLogo !== "" ? "file://" + doc.watermarkLogo : ""
            height: stage.markBox.rowH * stage.unit
            width: implicitHeight > 0 ? height * implicitWidth / implicitHeight : 0
            fillMode: Image.PreserveAspectFit
            sourceSize.height: stage.markBox.rowH * 2
            smooth: true
            mipmap: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: doc.watermarkText !== ""
            text: doc.watermarkText
            textFormat: Text.PlainText
            color: stage.markInk ? stage.markInk : "#ffffff"
            // Over a wallpaper or nothing at all there is no telling what is
            // underneath, so a light mark gets an outline to stand on.
            style: stage.markInk ? Text.Normal : Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.45)
            font.family: Model.textFamily("mono")
            font.weight: Font.DemiBold
            font.pixelSize: Math.max(1, Math.round(stage.markBox.size * stage.unit))
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
            title: stage.doc.frameTitle
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

    // What a magnifier looks through: the shot with every hidden area already
    // pixelated, so a lens over one shows the blocks and not what they cover.
    // Drawn 1:1 in shot pixels; the texture size is set, or it would follow
    // the screen's scale and resample.
    Item {
        id: lensSource
        visible: false
        width: Math.max(1, stage.geo.shotW)
        height: Math.max(1, stage.geo.shotH)

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: stage.codeKind ? codeSource : pixelSource
            textureSize: Qt.size(lensSource.width, lensSource.height)
            smooth: false
        }

        Repeater {
            model: stage.doc.annotations
            delegate: Pixelate {
                required property var model
                visible: model.kind === "redact"
                x: Math.min(model.x, model.x + model.w)
                y: Math.min(model.y, model.y + model.h)
                width: Math.max(1, Math.abs(model.w))
                height: Math.max(1, Math.abs(model.h))
                source: stage.codeKind ? codeSource : pixelSource
                area: Qt.rect(x, y, width, height)
                block: model.strength
            }
        }
    }

    // Over the picture and under the annotations: an arrow drawn on a dimmed
    // area stays as bright as one drawn on the spotlight.
    Spotlight {
        doc: stage.doc
        holeOffset: stage.geo.inset
        topRadius: stage.geo.chromeH > 0 ? 0 : stage.cardRadiusPx
        bottomRadius: stage.cardRadiusPx
        outlines: stage.doc.shotCount > 1 && stage.doc.sheet
                  ? Model.spotlightOutlines(stage.doc.sheet, topRadius, bottomRadius) : null
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
        magnifySource: lensSource
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
