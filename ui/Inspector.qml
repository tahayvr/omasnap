import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import "controls"
import "../lib/Model.js" as Model
import "../lib/Code.js" as Code

Flickable {
    id: insp
    property var doc
    property var systemThemes: []

    signal copyTextRequested()
    signal eyedropRequested(var done)

    // What the color picker is editing: "solid", "stop0" to "stop3" for the
    // custom gradient, or "" when it is closed.
    property string pickerTarget: ""
    // The first choice made after the picker opens is a new recent color;
    // those after it replace that one, so one visit leaves one color.
    property bool pickerFresh: true

    function openPicker(target) {
        insp.pickerTarget = insp.pickerTarget === target ? "" : target;
        insp.pickerFresh = true;
    }

    function pickedValue(target) {
        if (target === "solid") return String(doc.bgSolid);
        var i = parseInt(target.slice(4));
        return target.indexOf("stop") === 0 && i < doc.bgCustomStops.length ? doc.bgCustomStops[i] : "";
    }

    function applyPicked(target, hex) {
        if (target === "solid") {
            doc.bgSolid = hex;
        } else if (target.indexOf("stop") === 0) {
            var i = parseInt(target.slice(4));
            if (i >= doc.bgCustomStops.length) return;
            var stops = doc.bgCustomStops.slice();
            stops[i] = hex;
            doc.bgCustomStops = stops;
            insp.keepGradient();
        }
    }

    // A gradient is saved whole, so its colors are not also kept one by one.
    function commitPicked(target, hex) {
        insp.applyPicked(target, hex);
        if (target !== "solid") return;
        doc.customColors = Model.rememberColor(doc.customColors, hex, !insp.pickerFresh);
        insp.pickerFresh = false;
    }

    // Writes the gradient on show back to the saved one it came from.
    function keepGradient() {
        if (doc.bgCustomId === "") return;
        doc.userGradients = Model.saveGradient(doc.userGradients,
            { id: doc.bgCustomId, stops: doc.bgCustomStops, angle: doc.bgCustomAngle });
    }

    function setAngle(v) {
        doc.bgCustomAngle = Math.round(v);
        insp.keepGradient();
    }

    function showGradient(g) {
        doc.bgCustomStops = g.stops.slice();
        doc.bgCustomAngle = g.angle;
        doc.bgCustomId = g.id;
        doc.bgGradient = "custom";
    }

    // Starts from the gradient on show, which is usually the one about to be
    // adjusted, and opens it for editing.
    function newGradient() {
        var seed = Model.gradientSeed(doc.bgGradient, doc.bgCustomStops, doc.bgCustomAngle);
        var g = Model.cleanGradient({ id: Model.newGradientId(), stops: seed.stops, angle: seed.angle });
        doc.userGradients = Model.saveGradient(doc.userGradients, g);
        insp.showGradient(g);
    }

    // The card keeps it, as it keeps a deleted solid color; it just stops
    // being saved anywhere.
    function forgetGradient(id) {
        doc.userGradients = Model.forgetGradient(doc.userGradients, id);
        if (doc.bgCustomId === id) doc.bgCustomId = "";
    }

    // Forgetting one that was just picked would otherwise let the next pick
    // in the same visit replace the color after it instead.
    function forgetColor(hex) {
        doc.customColors = Model.forgetColor(doc.customColors, hex);
        insp.pickerFresh = true;
    }

    function addStop() {
        var stops = doc.bgCustomStops.slice();
        if (stops.length >= Model.CUSTOM_MAX_STOPS) return;
        stops.push(stops[stops.length - 1]);
        doc.bgCustomStops = stops;
        insp.keepGradient();
        insp.pickerTarget = "stop" + (stops.length - 1);
        insp.pickerFresh = true;
    }

    // The stop being edited if there is one, otherwise the last.
    function removeStop() {
        var stops = doc.bgCustomStops.slice();
        if (stops.length <= Model.CUSTOM_MIN_STOPS) return;
        var i = insp.pickerTarget.indexOf("stop") === 0 ? parseInt(insp.pickerTarget.slice(4)) : stops.length - 1;
        stops.splice(i, 1);
        doc.bgCustomStops = stops;
        insp.keepGradient();
        insp.pickerTarget = "";
    }

    Connections {
        target: insp.doc
        function onBgModeChanged() { insp.pickerTarget = ""; }
        function onBgGradientChanged() { if (insp.pickerTarget !== "solid") insp.pickerTarget = ""; }
        function onBgCustomIdChanged() { if (insp.pickerTarget !== "solid") insp.pickerTarget = ""; }
    }

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
                minWidth: Math.floor((width - Ui.gap * 2) / 3)   // two even rows of three
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

            // Kept apart from the presets, which cannot be removed.
            Column {
                width: parent.width
                spacing: Ui.gap
                visible: doc.bgMode === "gradient"

                Text {
                    text: "Your gradients"
                    color: Ui.textMuted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }

                Flow {
                    width: parent.width
                    spacing: Ui.gap
                    Repeater {
                        model: doc.userGradients
                        UserSwatch {
                            required property var modelData
                            stops: modelData.stops
                            active: doc.bgGradient === "custom" && doc.bgCustomId === modelData.id
                            onPicked: insp.showGradient(modelData)
                            onRemoved: insp.forgetGradient(modelData.id)
                        }
                    }
                    IconButton {
                        glyph: "+"
                        tip: "Save a gradient of your own, starting from this one"
                        implicitHeight: Ui.swatch
                        implicitWidth: Ui.swatch
                        onClicked: insp.newGradient()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Ui.row
                visible: doc.bgMode === "gradient" && doc.bgGradient === "custom"

                // Its own caption, or its + reads as a second "new gradient".
                Text {
                    text: "Colors"
                    color: Ui.textMuted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }

                Flow {
                    width: parent.width
                    spacing: Ui.gap
                    Repeater {
                        model: doc.bgCustomStops
                        Swatch {
                            required property var modelData
                            required property int index
                            swatchColor: modelData
                            active: insp.pickerTarget === "stop" + index
                            onPicked: insp.openPicker("stop" + index)
                        }
                    }
                    IconButton {
                        glyph: "+"
                        tip: "Add a color"
                        visible: doc.bgCustomStops.length < Model.CUSTOM_MAX_STOPS
                        implicitHeight: Ui.swatch
                        implicitWidth: Ui.swatch
                        onClicked: insp.addStop()
                    }
                    IconButton {
                        glyph: "\u2212"
                        tip: insp.pickerTarget.indexOf("stop") === 0 ? "Remove this color" : "Remove the last color"
                        visible: doc.bgCustomStops.length > Model.CUSTOM_MIN_STOPS
                        implicitHeight: Ui.swatch
                        implicitWidth: Ui.swatch
                        onClicked: insp.removeStop()
                    }
                }

                LabeledSlider {
                    label: "Angle"
                    value: doc.bgCustomAngle
                    from: 0; to: 359
                    suffix: "\u00b0"
                    onMoved: function (v) { insp.setAngle(v); }
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

            // Kept apart from the presets, which cannot be removed.
            Column {
                width: parent.width
                spacing: Ui.gap
                visible: doc.bgMode === "solid"

                Text {
                    text: "Your colors"
                    color: Ui.textMuted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }

                Flow {
                    width: parent.width
                    spacing: Ui.gap
                    Repeater {
                        model: doc.customColors
                        UserSwatch {
                            required property var modelData
                            swatchColor: modelData
                            active: Qt.colorEqual(doc.bgSolid, modelData)
                            onPicked: doc.bgSolid = modelData
                            onRemoved: insp.forgetColor(modelData)
                        }
                    }
                    IconButton {
                        glyph: "+"
                        tip: "Pick your own color"
                        active: insp.pickerTarget === "solid"
                        implicitHeight: Ui.swatch
                        implicitWidth: Ui.swatch
                        onClicked: insp.openPicker("solid")
                    }
                }
            }

            ColorPicker {
                visible: insp.pickerTarget !== ""
                value: insp.pickedValue(insp.pickerTarget)
                // The solid row already shows them all.
                recent: insp.pickerTarget === "solid" ? [] : doc.customColors
                onForgotten: function (hex) { insp.forgetColor(hex); }
                onEdited: function (hex) { insp.applyPicked(insp.pickerTarget, hex); }
                onCommitted: function (hex) { insp.commitPicked(insp.pickerTarget, hex); }
                onEyedropRequested: {
                    // Held, so the pick lands where it was asked for even if
                    // the picker moved on while the screen was up.
                    var target = insp.pickerTarget;
                    insp.eyedropRequested(function (hex) {
                        insp.pickerFresh = true;
                        insp.commitPicked(target, hex);
                    });
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
            title: doc.kind === "code" ? "Card" : "Screenshot"

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

            IconButton {
                width: parent.width
                visible: doc.kind === "shot"
                glyph: "⎘"
                label: "Copy the text in the shot"
                onClicked: insp.copyTextRequested()
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
