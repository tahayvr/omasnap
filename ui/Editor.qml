import QtQuick
import qs.Commons
import "controls"
import "../lib/Model.js" as Model

Rectangle {
    id: editor

    property var doc
    property var systemThemes: []
    property string saveDir: ""
    property string statusText: ""
    property bool busy: false

    signal captureRequested(string mode)
    signal codeRequested()
    signal copyRequested()
    signal dragOutRequested()
    signal saveRequested()
    signal saveAsRequested()
    signal openRequested()
    signal closeRequested()
    signal autoRedactRequested()
    signal copyTextRequested()
    signal eyedropRequested(var done)
    signal cropRequested()
    signal uncropRequested()

    // The drawing surface hovers as well as drags, so `held` says whether the
    // button is actually down. Every tool but crop had an annotation started
    // on press to check instead; crop had nothing, and its selection followed
    // the bare pointer around the picture. Callable, so the harness can hold
    // that behaviour down without a mouse.
    function drawMove(px, py, held) {
        if (!held) return;

        if (doc.tool === "crop") {
            var r = Model.cropRect(draw.ox, draw.oy, px - draw.ox, py - draw.oy,
                                   doc.shotWidth, doc.shotHeight);
            doc.cropRect = Qt.rect(r.x, r.y, r.w, r.h);
            return;
        }

        if (draw.activeId === "") return;
        var i = doc.indexOfId(draw.activeId);
        if (i < 0) return;
        if (doc.tool === "magnify") {
            var m = Model.magnifyFromDrag(draw.ox, draw.oy, px, py, doc.magnifyZoom);
            doc.updateAnnotation(draw.activeId, m);
            return;
        }
        doc.annotations.setProperty(i, "w", px - draw.ox);
        doc.annotations.setProperty(i, "h", py - draw.oy);
        // Every other tool draws itself from the delegate, which follows the
        // model on its own. The dim is one layer over the picture, so it only
        // redraws when the document says something changed.
        if (doc.tool === "spotlight") doc.annotationsEdited();
    }

    // Drawn over the area it shows, a magnifier is set beside it on release;
    // one too small to show anything is a stray drag.
    function finishMagnifier(uid) {
        var i = doc.indexOfId(uid);
        if (i < 0) return;
        var a = doc.annotations.get(i);
        var src = Model.magnifySource(a);
        if (src.r < Model.MIN_MAGNIFY) {
            doc.removeAnnotation(uid);
            return;
        }
        doc.updateAnnotation(uid, Model.placeMagnifier(src.x, src.y, src.r, a.zoom,
                                                       doc.shotWidth, doc.shotHeight));
        doc.annotationsEdited();
    }

    readonly property Item exportTarget: grabRoot
    readonly property string repoUrl: "https://github.com/tahayvr/postcard"
    // The settings take the inspector's place while they are open.
    property bool settingsOpen: false
    readonly property Item sidePanel: settingsPanel.visible ? settingsPanel
                                    : inspector.visible ? inspector : null
    // True from the moment the picture is ready until the drag ends: the
    // backdrop goes first, and the drag starts once it has.
    property bool draggingOut: false
    readonly property bool dragActive: dragOut.Drag.active

    // Called once the picture is on disk. A drag can only start while the
    // button is still held: Wayland ties it to that press.
    function startDragOut(path) {
        if (!dragOut.held) {
            editor.statusText = "Hold the button and drag it into another window";
            return;
        }
        var url = "file://" + path;
        dragOut.Drag.mimeData = { "text/uri-list": url + "\r\n" };
        dragOut.Drag.imageSource = url;
        editor.draggingOut = true;
        dragStart.restart();
    }

    Timer {
        id: dragStart
        interval: 150
        onTriggered: {
            if (!dragOut.held) { editor.draggingOut = false; return; }
            dragOut.Drag.active = true;
        }
    }

    color: Color.menu && Color.menu.background ? Color.menu.background : Color.background
    border.width: 1
    border.color: Color.menu && Color.menu.border ? Color.menu.border : Ui.hairline

    // Under everything: catches clicks that would otherwise reach the scrim
    // and close the editor, and takes focus back from text fields.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: editor.forceActiveFocus()
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Ui.button + Ui.pad

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Ui.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: Ui.row

            Wordmark {
                anchors.verticalCenter: parent.verticalCenter
                markHeight: Style.font.bodySmall * 1.5
                tint: Ui.text
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: doc.kind === "code" && doc.hasContent ? doc.frameTitle
                      : doc.shotName ? doc.shotName : "No screenshot yet"
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, Style.space(150))
            }
        }

        ToolOptions {
            anchors.centerIn: parent
            doc: editor.doc
            onCaptureRequested: function (mode) { editor.captureRequested(mode); }
            onCodeRequested: editor.codeRequested()
            onOpenRequested: editor.openRequested()
            onAutoRedactRequested: editor.autoRedactRequested()
            onCropRequested: editor.cropRequested()
            onUncropRequested: editor.uncropRequested()
            onEyedropRequested: function (done) { editor.eyedropRequested(done); }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Ui.pad / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Ui.gap

            IconButton {
                glyph: "\uf013"
                flat: true
                active: editor.settingsOpen
                tip: "Settings"
                onClicked: editor.settingsOpen = !editor.settingsOpen
            }
            // The overlay covers the screen, so the browser it opens would
            // sit behind it; close on the way out.
            IconButton {
                glyph: "\uf09b"
                flat: true
                tip: "Postcard on GitHub"
                onClicked: {
                    Qt.openUrlExternally(editor.repoUrl);
                    editor.closeRequested();
                }
            }
            IconButton {
                glyph: "\u2715"
                flat: true
                tip: "Close (Esc)"
                onClicked: editor.closeRequested()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Ui.hairline
        }
    }

    ToolRail {
        id: rail
        doc: editor.doc
        anchors { top: header.bottom; bottom: footer.top; left: parent.left }
        width: implicitWidth
        visible: doc.hasContent
        onStatus: function (text) { editor.statusText = text; }
    }

    Item {
        id: viewport
        anchors {
            top: header.bottom
            bottom: footer.top
            left: rail.visible ? rail.right : parent.left
            right: editor.sidePanel ? editor.sidePanel.left : parent.right
        }
        clip: true

        readonly property real margin: Ui.pad * 2
        // The stage is laid out in screen units, so a fit of 1 shows the shot
        // life-size, pixel for pixel; it is never magnified.
        readonly property real fit: doc.hasContent
            ? Math.min((width - margin * 2) / Math.max(1, stage.width),
                       (height - margin * 2) / Math.max(1, stage.height), 1)
            : 1

        // Checkerboard behind (never inside) the stage for a transparent
        // background. A tiled image, not a Canvas: a Canvas can skip its
        // paint when the window is re-mapped, which left the frame looking
        // see-through.
        Rectangle {
            anchors.fill: holder
            anchors.margins: -1
            visible: doc.bgMode === "none" && doc.hasContent
            color: "transparent"
            border.width: 1
            border.color: Ui.hairline
            Image {
                anchors.fill: parent
                anchors.margins: 1
                fillMode: Image.Tile
                smooth: false
                source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGYktHRAD/AP8A/6C9p5MAAAAHdElNRQfqCRMRCizhZEVqAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDI2LTA5LTE5VDE3OjEwOjQ0KzAwOjAwqwR2NQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyNi0wOS0xOVQxNzoxMDo0NCswMDowMNpZzokAAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjYtMDktMTlUMTc6MTA6NDQrMDA6MDCNTO9WAAAAEGNhTnYAAAAIAAAACAAAAAAAAAAAsu1W2QAAAChJREFUKM9jtLJ3YcAGBIWEsYozMZAIRjUQA1hwhff7d2+Hih+GgwYAZ8cEFYSK+YEAAAAASUVORK5CYII="
            }
        }

        Item {
            id: holder
            anchors.centerIn: parent
            width: stage.width * viewport.fit
            height: stage.height * viewport.fit
            visible: doc.hasContent

            // With the move tool, a press on nothing clears the selection and
            // a drag from there draws a box that selects whatever it touches;
            // with Shift it adds to what is already selected.
            MouseArea {
                id: marquee
                anchors.fill: parent
                enabled: doc.tool === "select"
                property point from: Qt.point(0, 0)
                property bool adding: false
                property bool boxing: false

                onPressed: function (e) {
                    marquee.from = Qt.point(e.x, e.y);
                    marquee.adding = (e.modifiers & Qt.ShiftModifier) !== 0;
                    marquee.boxing = false;
                    if (!marquee.adding) doc.selectedId = "";
                }
                onPositionChanged: function (e) {
                    if (!pressed) return;
                    if (Math.abs(e.x - marquee.from.x) + Math.abs(e.y - marquee.from.y) > 4)
                        marquee.boxing = true;
                    band.x = Math.min(e.x, marquee.from.x);
                    band.y = Math.min(e.y, marquee.from.y);
                    band.width = Math.abs(e.x - marquee.from.x);
                    band.height = Math.abs(e.y - marquee.from.y);
                }
                onReleased: {
                    if (!marquee.boxing) return;
                    marquee.boxing = false;
                    var a = draw.toShot(band.x, band.y);
                    var b = draw.toShot(band.x + band.width, band.y + band.height);
                    doc.selectInBox(a.x, a.y, b.x - a.x, b.y - a.y, marquee.adding);
                }
            }

            Rectangle {
                id: band
                z: 2
                visible: marquee.boxing
                color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
                border.width: 1
                border.color: Color.accent
            }

            // What the export grabs, rather than the stage itself: padded up
            // to a whole number of device pixels so grabToImage renders at
            // exactly 1:1 (see Model.grabSize), then cropped by postcard-deliver.
            Item {
                id: grabRoot
                // Over the drawing surface below, so the crop handles can
                // take a press; everything else in the stage ignores the
                // mouse while a tool is in hand, and falls through to it.
                z: 1
                readonly property var fit: Model.grabSize(stage.width, stage.height, stage.dpr)
                width: grabRoot.fit.w
                height: grabRoot.fit.h
                transformOrigin: Item.TopLeft
                scale: viewport.fit

                Stage {
                    id: stage
                    doc: editor.doc
                    interactive: true
                    viewScale: viewport.fit
                }
            }

            // Drawing surface; off in select mode so presses reach the annotations.
            MouseArea {
                id: draw
                anchors.fill: parent
                hoverEnabled: true
                enabled: doc.hasContent && doc.tool !== "select"
                acceptedButtons: Qt.LeftButton
                cursorShape: doc.tool === "select" ? Qt.ArrowCursor : Qt.CrossCursor

                property string activeId: ""
                property real ox: 0
                property real oy: 0

                function toShot(px, py) {
                    var k = viewport.fit * stage.unit;
                    return Qt.point(px / k - doc.geo.cardX - doc.geo.inset,
                                    py / k - doc.geo.cardY - doc.geo.chromeH - doc.geo.inset);
                }

                onPressed: function (e) {
                    if (doc.tool === "select") { doc.selectedId = ""; return; }
                    var p = toShot(e.x, e.y);
                    ox = p.x; oy = p.y;

                    if (doc.tool === "crop") {
                        doc.selectedId = "";
                        doc.cropRect = Qt.rect(0, 0, 0, 0);
                        activeId = "";
                        return;
                    }

                    var a = Model.newAnnotation(doc.tool, p.x, p.y);
                    a.color = String(doc.inkColor);
                    a.width = doc.inkWidth;
                    if (doc.tool === "arrow") a.style = String(doc.arrowStyle);

                    if (doc.tool === "step") {
                        var size = Math.max(22, Math.round(doc.inkWidth * 9));
                        doc.stepCounter += 1;
                        a.index = doc.stepCounter;
                        a.x = p.x - size / 2; a.y = p.y - size / 2;
                        a.w = size; a.h = size;
                        doc.addAnnotation(a);
                        activeId = "";
                        return;
                    }
                    if (doc.tool === "text") {
                        a.w = 0; a.h = 0;
                        a.text = "";
                        a.font = doc.textFont;
                        a.fontSize = doc.textSize > 0 ? doc.textSize
                                   : Model.defaultTextSize(doc.shotWidth, doc.shotHeight);
                        doc.addAnnotation(a);
                        activeId = "";
                        doc.tool = "select";
                        editor.statusText = "Type the label, then press Enter";
                        return;
                    }
                    if (doc.tool === "magnify") {
                        a.zoom = doc.magnifyZoom;
                        a.sx = Math.round(p.x);
                        a.sy = Math.round(p.y);
                    }
                    a.strength = Math.max(6, Math.round(doc.geo.shotW / 90));
                    doc.addAnnotation(a);
                    activeId = a.uid;
                }

                onPositionChanged: function (e) {
                    var p = toShot(e.x, e.y);
                    editor.drawMove(p.x, p.y, draw.pressed);
                }

                onReleased: function () {
                    if (doc.tool === "crop") {
                        if (!doc.cropUsable) doc.cropRect = Qt.rect(0, 0, 0, 0);
                        return;
                    }
                    if (activeId === "") return;
                    var i = doc.indexOfId(activeId);
                    if (i >= 0 && doc.annotations.get(i).kind === "magnify") {
                        editor.finishMagnifier(activeId);
                        activeId = "";
                        return;
                    }
                    if (i >= 0) {
                        var a = doc.annotations.get(i);
                        if (Math.abs(a.w) < 4 && Math.abs(a.h) < 4)
                            doc.removeAnnotation(activeId);
                        else
                            doc.annotationsEdited();
                    }
                    activeId = "";
                }
            }

        }

        Column {
            anchors.centerIn: parent
            spacing: Ui.pad
            visible: !doc.hasContent
            width: Math.min(parent.width - Ui.pad * 4, Style.space(380))

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Take a shot to start"
                color: Ui.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Grab a region, a window or the screen, or turn selected text into a code card."
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                lineHeight: 1.35
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Ui.gap
                IconButton { glyph: "\u2b1a"; label: "Capture a region"; onClicked: editor.captureRequested("region") }
                IconButton { glyph: "\u2039\u203a"; label: "Code from selection"; onClicked: editor.codeRequested() }
                IconButton { glyph: "\uf1c5"; label: "Open a file"; onClicked: editor.openRequested() }
            }
        }
    }

    Inspector {
        id: inspector
        doc: editor.doc
        systemThemes: editor.systemThemes
        anchors { top: header.bottom; bottom: footer.top; right: parent.right }
        width: Style.space(300)
        visible: doc.hasContent && !editor.settingsOpen
        onCopyTextRequested: editor.copyTextRequested()
        onEyedropRequested: function (done) { editor.eyedropRequested(done); }
    }

    Settings {
        id: settingsPanel
        doc: editor.doc
        saveDir: editor.saveDir
        anchors { top: header.bottom; bottom: footer.top; right: parent.right }
        width: inspector.width
        visible: editor.settingsOpen
    }

    Rectangle {
        visible: rail.visible
        anchors { left: rail.right; top: rail.top; bottom: rail.bottom }
        width: 1
        color: Ui.hairline
    }

    Rectangle {
        visible: editor.sidePanel !== null
        anchors { right: editor.sidePanel ? editor.sidePanel.left : parent.right
                  top: header.bottom; bottom: footer.top }
        width: 1
        color: Ui.hairline
    }

    Item {
        id: footer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: Ui.button + Ui.pad

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Ui.hairline
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Ui.pad
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - Style.space(400))
            elide: Text.ElideRight
            text: editor.statusText !== "" ? editor.statusText
                  : doc.outputTooLarge ? "Too large to render at " + doc.exportScale + "\u00d7 \u2014 pick a smaller export scale"
                  : (doc.hasContent ? Math.round(viewport.fit * 100) + "%  \u00b7  "
                                   + doc.geo.frameW + "\u00d7" + doc.geo.frameH
                                   + " \u2192 " + doc.outWidth + "\u00d7" + doc.outHeight
                                 : "")
            color: editor.statusText !== "" ? Ui.text : Ui.textMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Ui.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: Ui.gap
            visible: doc.hasContent

            IconButton {
                glyph: "\u21ba"
                tip: "Reset styling"
                flat: true
                onClicked: doc.reset()
            }
            IconButton {
                id: dragOut
                glyph: "\uf0b2"
                label: "Drag"
                tip: "Hold and drag the picture into another app"
                onPressStarted: editor.dragOutRequested()

                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.proposedAction: Qt.CopyAction
                // The picture itself would be the size of the export.
                Drag.imageSourceSize: Qt.size(Style.space(200),
                                              Style.space(200) * doc.outHeight / Math.max(1, doc.outWidth))
                // Not told whether it was taken: Qt reports no action even
                // for a drop another window accepted.
                Drag.onDragFinished: editor.draggingOut = false
            }
            IconButton {
                glyph: "\u2398"
                label: editor.busy ? "Working\u2026" : "Copy"
                onClicked: editor.copyRequested()
            }
            IconButton {
                glyph: "\uf0c7"
                flat: true
                tip: "Save as\u2026 (Ctrl+Shift+S)"
                onClicked: editor.saveAsRequested()
            }
            IconButton {
                glyph: "\u2193"
                label: "Save"
                tip: "Save to " + editor.saveDir + " (Ctrl+S)"
                primary: true
                onClicked: editor.saveRequested()
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 3200
        onTriggered: editor.statusText = ""
    }
    onStatusTextChanged: if (statusText !== "") statusTimer.restart()
}
