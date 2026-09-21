import QtQuick
import qs.Commons
import "controls"
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

    readonly property var inkTools: ["arrow", "box", "ellipse", "highlight", "text", "step"]

    sourceComponent: {
        if (!doc.hasContent || doc.tool === "select") return captureComp;
        if (doc.tool === "spotlight") return spotlightComp;
        if (doc.tool === "redact") return redactComp;
        if (opts.inkTools.indexOf(doc.tool) !== -1) return inkComp;
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
            IconButton { glyph: "⬜"; label: "Screen"; onClicked: opts.captureRequested("fullscreen") }
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
                Repeater {
                    model: ["#ff5f56", "#ffbd2e", "#27c93f", "#4aa6c7", "#b0577f", "#ffffff", "#111111"]
                    Swatch {
                        required property var modelData
                        swatchColor: modelData
                        active: Qt.colorEqual(opts.doc.inkColor, modelData)
                        onPicked: opts.doc.inkColor = modelData
                    }
                }
                Swatch {
                    swatchColor: Color.accent
                    active: Qt.colorEqual(opts.doc.inkColor, Color.accent)
                    onPicked: opts.doc.inkColor = Color.accent
                }
            }

            InlineSlider {
                label: opts.doc.tool === "text" ? "Size" : "Stroke"
                value: opts.doc.inkWidth
                from: 1; to: 16
                onMoved: function (v) { opts.doc.inkWidth = Math.round(v); }
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
