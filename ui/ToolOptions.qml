import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "controls"
import "../lib/Model.js" as Model
import "../lib/Redact.js" as Redact

// The middle of the header: what the current tool is for, rather than a fixed
// strip of controls. With nothing to draw on, or with the move tool, that is
// the ways to get a picture in; with a tool picked, it is that tool's options,
// which is why the inspector on the right is only about the picture itself.
Loader {
    id: opts

    property var doc

    signal captureRequested(string mode)
    signal codeRequested()
    signal openRequested()
    signal autoRedactRequested()
    signal cropRequested()
    signal uncropRequested()
    signal eyedropRequested(var done)

    readonly property var inkTools: ["arrow", "box", "ellipse", "highlight", "text", "step", "magnify"]

    // The mark in hand, if one is selected: the strip is then about that
    // rather than about the tool, so a mark can be restyled after the fact.
    readonly property var picked: {
        doc.selectedId;
        doc.annotationRevision;
        return doc.hasContent ? doc.selectedAnnotation() : null;
    }
    readonly property string subject: opts.picked ? String(opts.picked.kind) : doc.tool
    readonly property color ink: (opts.picked && opts.picked.color && opts.picked.color !== "")
                                 ? opts.picked.color : doc.inkColor
    readonly property real stroke: opts.picked ? opts.picked.width : doc.inkWidth
    readonly property string arrowStyle: (opts.picked && opts.picked.style && opts.picked.style !== "")
                                         ? opts.picked.style : doc.arrowStyle
    readonly property string textFont: (opts.picked && opts.picked.kind === "text" && opts.picked.font)
                                       ? opts.picked.font : doc.textFont
    readonly property int zoom: opts.picked && opts.picked.kind === "magnify"
                                ? opts.picked.zoom : doc.magnifyZoom

    // Both at once: what is in hand changes, and so does what the next mark
    // will be made with.
    function setInk(c) {
        doc.inkColor = c;
        doc.styleSelection("color", String(c));
    }
    // As in the inspector: every pick in one visit to the picker replaces the
    // color that visit saved, so dragging across the field keeps one color,
    // not every color it passed over.
    property bool pickerFresh: true

    function keepInk(hex) {
        opts.setInk(hex);
        doc.inkColors = Model.rememberColor(doc.inkColors, hex, !opts.pickerFresh,
                                            Model.INK_COLORS_KEPT);
        opts.pickerFresh = false;
    }

    function forgetInk(hex) {
        doc.inkColors = Model.forgetColor(doc.inkColors, hex);
        opts.pickerFresh = true;
    }

    function setStroke(v) {
        doc.inkWidth = v;
        doc.styleSelection("width", v);
    }

    sourceComponent: {
        if (!doc.hasContent) return captureComp;
        if (opts.subject === "crop") return cropComp;
        if (opts.subject === "spotlight") return spotlightComp;
        if (opts.subject === "redact") return redactComp;
        if (opts.inkTools.indexOf(opts.subject) !== -1) return inkComp;
        return captureComp;
    }

    // A strip that changes under the pointer is easy to miss; fade each one in.
    onSourceComponentChanged: fade.restart()
    NumberAnimation {
        id: fade
        target: opts
        property: "opacity"
        from: 0.2
        to: 1
        duration: 140
    }

    Component {
        id: captureComp
        Row {
            spacing: Ui.gap
            IconButton { glyph: "⬚"; label: "Region"; onClicked: opts.captureRequested("region") }
            IconButton { glyph: "◰"; label: "Window"; onClicked: opts.captureRequested("windows") }

            // Joined, since the delay belongs to Screen alone: region and
            // window pickers wait for a click anyway, which closes any menu.
            Row {
                IconButton {
                    glyph: "⬜"
                    label: "Screen"
                    tip: CaptureDelay.seconds
                         ? "Capture the whole screen in " + CaptureDelay.seconds + " seconds"
                         : "Capture the whole screen"
                    onClicked: opts.captureRequested("fullscreen")
                }
                Rectangle { width: 1; height: Ui.button; color: Ui.hairline }
                IconButton {
                    glyph: "◷"
                    label: CaptureDelay.label(CaptureDelay.seconds)
                    rest: Ui.fillRaised
                    active: CaptureDelay.seconds > 0
                    tip: "Delay before the screen is captured, click to change"
                    onClicked: CaptureDelay.cycle()
                }
            }
            IconButton { glyph: "‹›"; label: "Code"; tip: "Selected text as a code card"; onClicked: opts.codeRequested() }
            IconButton { glyph: ""; label: "File"; tip: "Open a file"; onClicked: opts.openRequested() }
        }
    }

    Component {
        id: inkComp
        Row {
            spacing: Ui.row

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.gap
                visible: opts.subject === "text"
                Repeater {
                    model: Model.TEXT_FONTS
                    IconButton {
                        required property var modelData
                        label: modelData.label
                        tip: modelData.family
                        active: opts.textFont === modelData.key
                        onClicked: opts.doc.setTextFont(modelData.key)
                    }
                }
            }

            // Only arrows have more than one shape to draw.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.gap
                visible: opts.subject === "arrow"
                Repeater {
                    model: Model.ARROW_STYLES
                    IconButton {
                        required property var modelData
                        glyph: modelData.glyph
                        tip: modelData.label
                        active: opts.arrowStyle === modelData.key
                        onClicked: opts.doc.setArrowStyle(modelData.key)
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.gap
                Repeater {
                    model: ["#ff5f56", "#ffbd2e", "#27c93f", "#4aa6c7", "#b0577f", "#ffffff", "#111111"]
                    Swatch {
                        required property var modelData
                        swatchColor: modelData
                        active: Qt.colorEqual(opts.ink, modelData)
                        onPicked: opts.setInk(modelData)
                    }
                }
                Swatch {
                    swatchColor: Color.accent
                    active: Qt.colorEqual(opts.ink, Color.accent)
                    onPicked: opts.setInk(Color.accent)
                }

                Repeater {
                    model: opts.doc.inkColors
                    UserSwatch {
                        required property var modelData
                        swatchColor: modelData
                        active: Qt.colorEqual(opts.ink, modelData)
                        onPicked: opts.setInk(modelData)
                        onRemoved: opts.forgetInk(modelData)
                    }
                }

                IconButton {
                    id: addInk
                    glyph: "+"
                    tip: "Pick your own color"
                    active: inkPopup.opened
                    implicitWidth: Ui.swatch
                    implicitHeight: Ui.swatch
                    onClicked: {
                        if (inkPopup.opened) { inkPopup.close(); return; }
                        opts.pickerFresh = true;
                        inkPopup.open();
                    }

                    QQC.Popup {
                        id: inkPopup
                        x: Math.round((addInk.width - width) / 2)
                        y: addInk.height + Ui.gap
                        width: Ui.popover
                        padding: Ui.pad
                        // Escape closes the picker rather than the editor.
                        focus: true
                        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

                        background: Rectangle {
                            color: Color.menu && Color.menu.background ? Color.menu.background : Color.background
                            border.width: 1
                            border.color: Ui.borderActive
                        }

                        ColorPicker {
                            width: inkPopup.availableWidth
                            value: String(opts.ink)
                            onEdited: function (hex) { opts.setInk(hex); }
                            onCommitted: function (hex) { opts.keepInk(hex); }
                            onEyedropRequested: {
                                opts.eyedropRequested(function (hex) {
                                    opts.pickerFresh = true;
                                    opts.keepInk(hex);
                                });
                            }
                        }
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.gap
                visible: opts.subject === "magnify"
                Repeater {
                    model: Model.MAGNIFY_ZOOMS
                    IconButton {
                        required property var modelData
                        label: modelData + "\u00d7"
                        tip: "Zoom " + modelData + " times"
                        active: opts.zoom === modelData
                        onClicked: opts.doc.setMagnifyZoom(modelData)
                    }
                }
            }

            InlineSlider {
                // Neither a step badge nor a label has a stroke; both are
                // sized by the handles on them.
                visible: opts.subject !== "step" && opts.subject !== "text"
                label: "Stroke"
                value: opts.stroke
                from: 1; to: 16
                onMoved: function (v) { opts.setStroke(Math.round(v)); }
            }
        }
    }

    Component {
        id: spotlightComp
        Row {
            spacing: Ui.row

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.gap
                IconButton {
                    glyph: "□"
                    label: "Rectangle"
                    active: opts.doc.spotShape === "rect"
                    onClicked: opts.doc.spotShape = "rect"
                }
                IconButton {
                    glyph: "○"
                    label: "Ellipse"
                    active: opts.doc.spotShape === "ellipse"
                    onClicked: opts.doc.spotShape = "ellipse"
                }
            }

            InlineSlider {
                label: "Dim"
                value: opts.doc.spotDim
                from: 0; to: 90
                suffix: "%"
                onMoved: function (v) { opts.doc.spotDim = Math.round(v); }
            }
        }
    }

    Component {
        id: cropComp
        Row {
            spacing: Ui.gap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: opts.doc.cropUsable
                      ? Math.round(opts.doc.cropRect.width) + " \u00d7 " + Math.round(opts.doc.cropRect.height) + " px"
                      : "Drag over the part to keep"
                color: opts.doc.cropUsable ? Ui.text : Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }

            IconButton {
                glyph: "\uf125"
                label: "Crop"
                primary: opts.doc.cropUsable
                enabled: opts.doc.cropUsable
                tip: "Keep the selection (Enter)"
                onClicked: opts.cropRequested()
            }

            IconButton {
                visible: opts.doc.cropped
                glyph: "\u21ba"
                label: "Whole picture"
                tip: "Back to the picture as it came in"
                onClicked: opts.uncropRequested()
            }
        }
    }

    Component {
        id: redactComp
        Row {
            spacing: Ui.gap

            // OCR has no text to find on a code card, so there only the
            // manual blocks are on offer.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: opts.doc.kind !== "shot"
                text: "Drag over anything to pixelate it"
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }

            Repeater {
                model: opts.doc.kind === "shot" ? Redact.CLASSES : []
                Chip {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    label: modelData.short
                    on: opts.doc.redactClasses.indexOf(modelData.key) !== -1
                    onToggled: {
                        var c = opts.doc.redactClasses.slice();
                        var i = c.indexOf(modelData.key);
                        if (i === -1) c.push(modelData.key); else c.splice(i, 1);
                        opts.doc.redactClasses = c;
                    }
                }
            }

            IconButton {
                visible: opts.doc.kind === "shot"
                glyph: "░"
                label: "Find and hide"
                tip: "Pixelate everything the classes above match"
                onClicked: opts.autoRedactRequested()
            }
        }
    }
}
