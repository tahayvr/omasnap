import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "controls"
import "../lib/Model.js" as Model
import "../lib/Redact.js" as Redact
import "../lib/Code.js" as Code

Flickable {
    id: insp
    property var doc
    property var systemThemes: []

    signal autoRedactRequested()
    signal copyTextRequested()

    contentWidth: width
    contentHeight: col.implicitHeight + Ui.pad * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Always on when there is more below: at the default height the export
    // controls sit past the fold, and nothing else says so.
    QQC.ScrollBar.vertical: QQC.ScrollBar {
        id: vbar
        policy: QQC.ScrollBar.AlwaysOn
        visible: vbar.size < 1
        hoverEnabled: true
        background: null
        contentItem: Rectangle {
            implicitWidth: Style.space(3)
            color: Ui.tint(vbar.pressed ? 0.45 : vbar.hovered ? 0.32 : 0.18)
        }
    }

    Column {
        id: col
        x: Ui.pad
        y: Ui.pad
        width: insp.width - Ui.pad * 2
        spacing: Ui.section

        Section {
            title: "Code"
            visible: doc.kind === "code"

            Dropdown {
                current: doc.codeTheme
                visibleRows: 12          // the list is long once themes load
                // Omarchy first, then every theme installed on this system,
                // then bat's own for the palettes Omarchy does not ship.
                options: [{ key: "omarchy", label: "Omarchy" }]
                    .concat(insp.systemThemes)
                    .concat(Code.THEMES.slice(1).map(function (t) {
                        return { key: t.key, label: t.label };
                    }))
                onPicked: function (k) { doc.codeTheme = k; }
            }

            Dropdown {
                current: doc.codeLang
                options: Code.LANGUAGES.map(function (l) {
                    return { key: l.key, label: l.key === "auto" ? "Auto (" + Code.languageLabel(doc.codeDetected) + ")" : l.label };
                })
                onPicked: function (k) { doc.codeLang = k; }
            }

            LabeledSlider {
                label: "Font size"
                value: doc.codeFont
                from: 10; to: 32; decimals: 0; suffix: " px"
                onMoved: function (v) { doc.codeFont = Math.round(v); }
            }

            Toggle {
                label: "Line numbers"
                checked: doc.codeNumbers
                onToggled: function (v) { doc.codeNumbers = v; }
            }
        }

        Section {
            title: "Background"

            Segmented {
                current: doc.bgMode
                options: [
                    { key: "auto",     label: "Auto" },
                    { key: "gradient", label: "Gradient" },
                    { key: "solid",    label: "Solid" },
                    { key: "theme",    label: "Theme" },
                    { key: "desktop",  label: "Desktop" },
                    { key: "none",     label: "None" }
                ]
                onPicked: function (k) { doc.bgMode = k; }
            }

            Text {
                width: parent.width
                visible: doc.kind === "shot" && doc.bgMode === "auto" && doc.autoPalette.length === 0
                wrapMode: Text.WordWrap
                text: "Sampling the screenshot…"
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }

            Flow {
                width: parent.width
                spacing: Ui.gap
                visible: doc.kind === "shot" && doc.bgMode === "auto" && doc.autoPalette.length > 0
                Repeater {
                    model: doc.autoPalette
                    Swatch {
                        required property var modelData
                        required property int index
                        swatchColor: modelData
                        active: index === 0
                        onPicked: {
                            var p = doc.autoPalette.slice();
                            p.unshift(p.splice(index, 1)[0]);
                            doc.autoPalette = p;
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: Ui.gap
                visible: doc.bgMode === "gradient"
                Repeater {
                    model: Model.GRADIENTS
                    Rectangle {
                        id: swatch
                        required property var modelData
                        width: Ui.tile
                        height: Ui.swatch
                        border.width: doc.bgGradient === modelData.key ? 2 : (ma.containsMouse ? 1 : 0)
                        border.color: doc.bgGradient === modelData.key ? Color.foreground : Ui.textMuted
                        // Same five slots as the stage, so a preset that turns
                        // through a color previews as one. Addressed by id: a
                        // GradientStop's `parent` is not the Rectangle, and the
                        // swatches came out black when they were written that way.
                        readonly property bool mesh: Model.gradientIsMesh(modelData)
                        readonly property var stops: Model.gradientStops(modelData.stops)

                        MeshGradient {
                            anchors.fill: parent
                            visible: swatch.mesh
                            base: swatch.mesh ? swatch.modelData.base : "transparent"
                            points: swatch.mesh ? Model.meshPoints(swatch.modelData) : []
                        }

                        gradient: swatch.mesh ? null : linear
                        Gradient {
                            id: linear
                            orientation: Gradient.Horizontal
                            GradientStop { position: swatch.stops[0].at; color: swatch.stops[0].color }
                            GradientStop { position: swatch.stops[1].at; color: swatch.stops[1].color }
                            GradientStop { position: swatch.stops[2].at; color: swatch.stops[2].color }
                            GradientStop { position: swatch.stops[3].at; color: swatch.stops[3].color }
                            GradientStop { position: swatch.stops[4].at; color: swatch.stops[4].color }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: doc.bgGradient = modelData.key
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: Ui.gap
                visible: doc.bgMode === "solid"
                Repeater {
                    model: ["#0d0d12", "#1e222a", "#2d333f", "#f2f2f2", "#e8e2d5",
                            "#1b3a4b", "#3c1f4a", "#4a2b1f", "#20402c"]
                    Swatch {
                        required property var modelData
                        swatchColor: modelData
                        active: Qt.colorEqual(doc.bgSolid, modelData)
                        onPicked: doc.bgSolid = modelData
                    }
                }
            }
        }

        Section {
            title: "Framing"

            LabeledSlider {
                label: "Padding"
                value: doc.padding
                from: 0; to: 30; decimals: 1; suffix: "%"
                onMoved: function (v) { doc.padding = v; }
            }

            LabeledSlider {
                label: "Inset"
                value: doc.inset
                from: 0; to: 20; decimals: 1; suffix: "%"
                onMoved: function (v) { doc.inset = v; }
            }

            Segmented {
                current: doc.ratio
                minWidth: Style.space(48)
                options: Model.RATIOS.map(function (r) { return { key: r.key, label: r.label }; })
                onPicked: function (k) { doc.ratio = k; }
            }
        }

        Section {
            title: "Screenshot"

            LabeledSlider {
                label: "Corner radius"
                value: doc.radius
                from: 0; to: 25; decimals: 1; suffix: "%"
                onMoved: function (v) { doc.radius = v; }
            }
            LabeledSlider {
                label: "Shadow"
                value: doc.shadow
                from: 0; to: 100; decimals: 0
                onMoved: function (v) { doc.shadow = v; }
            }

            Segmented {
                current: doc.frame
                options: [
                    { key: "none",     label: "No frame" },
                    { key: "titlebar", label: "Title bar" }
                ]
                onPicked: function (k) { doc.frame = k; }
            }

            TextBox {
                id: titleInput
                visible: doc.frame === "titlebar"
                placeholder: "Window title"
                text: doc.frameTitle
                onTextChanged: if (doc.frameTitle !== text) doc.frameTitle = text
                onDone: insp.forceActiveFocus()
                // Typing breaks the binding above; follow the document by hand.
                Connections {
                    target: doc
                    function onFrameTitleChanged() {
                        if (titleInput.text !== doc.frameTitle) titleInput.text = doc.frameTitle;
                    }
                }
            }
        }

        Section {
            title: "Ink"

            Flow {
                width: parent.width
                spacing: Ui.gap
                Repeater {
                    model: ["#ff5f56", "#ffbd2e", "#27c93f", "#4aa6c7", "#b0577f", "#ffffff", "#111111"]
                    Swatch {
                        required property var modelData
                        swatchColor: modelData
                        active: Qt.colorEqual(doc.inkColor, modelData)
                        onPicked: doc.inkColor = modelData
                    }
                }
                Swatch {
                    swatchColor: Color.accent
                    active: Qt.colorEqual(doc.inkColor, Color.accent)
                    onPicked: doc.inkColor = Color.accent
                }
            }

            LabeledSlider {
                label: "Stroke"
                value: doc.inkWidth
                from: 1; to: 16; decimals: 0
                onMoved: function (v) { doc.inkWidth = v; }
            }
        }

        Section {
            title: "Hide sensitive data"
            visible: doc.kind === "shot"

            Flow {
                width: parent.width
                spacing: Ui.gap
                Repeater {
                    model: Redact.CLASSES
                    Chip {
                        required property var modelData
                        label: modelData.label
                        on: doc.redactClasses.indexOf(modelData.key) !== -1
                        onToggled: {
                            var c = doc.redactClasses.slice();
                            var i = c.indexOf(modelData.key);
                            if (i === -1) c.push(modelData.key); else c.splice(i, 1);
                            doc.redactClasses = c;
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Ui.gap
                IconButton {
                    width: (parent.width - Ui.gap) / 2
                    glyph: "░"
                    label: "Find and hide"
                    onClicked: insp.autoRedactRequested()
                }
                IconButton {
                    width: (parent.width - Ui.gap) / 2
                    glyph: "⎘"
                    label: "Copy text"
                    onClicked: insp.copyTextRequested()
                }
            }
        }

        // Below the framing controls it belongs with, but out of the way:
        // off by default and rarely reached for.
        Toggle {
            label: "Optical balance"
            hint: "Lifts the shot slightly so it does not read as sitting low"
            checked: doc.balance
            onToggled: function (v) { doc.balance = v; }
        }

        Section {
            title: "Export"

            Row {
                width: parent.width
                spacing: Ui.row
                Segmented {
                    minWidth: Style.space(44); width: minWidth * 3 + Ui.gap * 2
                    current: String(doc.exportScale)
                    options: [{ key: "1", label: "1×" }, { key: "2", label: "2×" }, { key: "3", label: "3×" }]
                    onPicked: function (k) { doc.exportScale = parseInt(k, 10); }
                }
                Segmented {
                    minWidth: Style.space(52); width: minWidth * 2 + Ui.gap
                    current: doc.format
                    options: [{ key: "png", label: "PNG" }, { key: "jpg", label: "JPEG" }]
                    onPicked: function (k) { doc.format = k; }
                }
            }

            LabeledSlider {
                visible: doc.format === "jpg"
                label: "Quality"
                value: doc.quality
                from: 40; to: 100; decimals: 0
                onMoved: function (v) { doc.quality = v; }
            }

            Text {
                width: parent.width
                text: doc.outWidth + " × " + doc.outHeight + " px"
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }

    }
}
