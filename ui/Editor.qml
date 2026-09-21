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
    signal saveRequested()
    signal saveAsRequested()
    signal openRequested()
    signal closeRequested()
    signal autoRedactRequested()
    signal copyTextRequested()

    readonly property Item exportTarget: grabRoot
    readonly property string repoUrl: "https://github.com/tahayvr/omasnap"

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
                      : doc.shotPath ? doc.shotPath.split("/").pop() : "No screenshot yet"
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
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Ui.pad / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Ui.gap

            // The overlay covers the screen, so the browser it opens would
            // sit behind it; close on the way out.
            IconButton {
                glyph: "\uf09b"
                flat: true
                tip: "OmaSnap on GitHub"
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
            right: inspector.visible ? inspector.left : parent.right
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

            MouseArea {
                anchors.fill: parent
                enabled: doc.tool === "select"
                onClicked: doc.selectedId = ""
            }

            // What the export grabs, rather than the stage itself: padded up
            // to a whole number of device pixels so grabToImage renders at
            // exactly 1:1 (see Model.grabSize), then cropped by snap-deliver.
            Item {
                id: grabRoot
                readonly property var fit: Model.grabSize(stage.width, stage.height, stage.dpr)
                width: grabRoot.fit.w
                height: grabRoot.fit.h
                transformOrigin: Item.TopLeft
                scale: viewport.fit

                Stage {
                    id: stage
                    doc: editor.doc
                    interactive: true
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

                    var a = Model.newAnnotation(doc.tool, p.x, p.y);
                    a.color = String(doc.inkColor);
                    a.width = doc.inkWidth;

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
                        doc.addAnnotation(a);
                        activeId = "";
                        doc.tool = "select";
                        editor.statusText = "Type the label, then press Enter";
                        return;
                    }
                    a.strength = Math.max(6, Math.round(doc.geo.shotW / 90));
                    doc.addAnnotation(a);
                    activeId = a.uid;
                }

                onPositionChanged: function (e) {
                    if (activeId === "") return;
                    var p = toShot(e.x, e.y);
                    var i = doc.indexOfId(activeId);
                    if (i < 0) return;
                    doc.annotations.setProperty(i, "w", p.x - ox);
                    doc.annotations.setProperty(i, "h", p.y - oy);
                    // Every other tool draws itself from the delegate, which
                    // follows the model on its own. The dim is one layer over
                    // the picture, so it only redraws when the document says
                    // something changed.
                    if (doc.tool === "spotlight") doc.annotationsEdited();
                }

                onReleased: function () {
                    if (activeId === "") return;
                    var i = doc.indexOfId(activeId);
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
        visible: doc.hasContent
        onCopyTextRequested: editor.copyTextRequested()
    }

    Rectangle {
        visible: rail.visible
        anchors { left: rail.right; top: rail.top; bottom: rail.bottom }
        width: 1
        color: Ui.hairline
    }

    Rectangle {
        visible: inspector.visible
        anchors { right: inspector.left; top: inspector.top; bottom: inspector.bottom }
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
