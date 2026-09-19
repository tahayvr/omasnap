import QtQuick
import qs.Commons
import "controls"
import "../lib/Model.js" as Model

Rectangle {
    id: editor

    property var doc
    property string statusText: ""
    property bool busy: false

    signal captureRequested(string mode)
    signal copyRequested()
    signal saveRequested()
    signal openRequested()
    signal closeRequested()
    signal autoRedactRequested()
    signal copyTextRequested()

    readonly property Item exportTarget: stage

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

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "OmaSnap"
                color: Ui.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: doc.shotPath ? doc.shotPath.split("/").pop() : "No screenshot yet"
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, Style.space(220))
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Ui.gap

            IconButton { glyph: "\u2b1a"; label: "Region"; onClicked: editor.captureRequested("region") }
            IconButton { glyph: "\u25f0"; label: "Window"; onClicked: editor.captureRequested("windows") }
            IconButton { glyph: "\u2b1c"; label: "Screen"; onClicked: editor.captureRequested("fullscreen") }
            IconButton { glyph: "\u2026"; tip: "Open a file"; onClicked: editor.openRequested() }
        }

        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: Ui.pad / 2
            anchors.verticalCenter: parent.verticalCenter
            glyph: "\u2715"
            flat: true
            tip: "Close (Esc)"
            onClicked: editor.closeRequested()
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
        visible: doc.hasShot
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
        readonly property real fit: doc.hasShot
            ? Math.min((width - margin * 2) / Math.max(1, stage.width),
                       (height - margin * 2) / Math.max(1, stage.height), 1)
            : 1

        // Checkerboard behind (never inside) the stage for transparent backgrounds.
        Canvas {
            anchors.fill: holder
            visible: doc.bgMode === "none" && doc.hasShot
            onPaint: {
                var ctx = getContext("2d"), s = 10;
                ctx.fillStyle = "#2a2a2a"; ctx.fillRect(0, 0, width, height);
                ctx.fillStyle = "#343434";
                for (var y = 0; y < height; y += s)
                    for (var x = 0; x < width; x += s)
                        if (((x / s) + (y / s)) % 2 === 0) ctx.fillRect(x, y, s, s);
            }
        }

        Item {
            id: holder
            anchors.centerIn: parent
            width: stage.width * viewport.fit
            height: stage.height * viewport.fit
            visible: doc.hasShot

            MouseArea {
                anchors.fill: parent
                enabled: doc.tool === "select"
                onClicked: doc.selectedId = ""
            }

            Stage {
                id: stage
                doc: editor.doc
                interactive: true
                transformOrigin: Item.TopLeft
                scale: viewport.fit
            }

            // Drawing surface; off in select mode so presses reach the annotations.
            MouseArea {
                id: draw
                anchors.fill: parent
                hoverEnabled: true
                enabled: doc.hasShot && doc.tool !== "select"
                acceptedButtons: Qt.LeftButton
                cursorShape: doc.tool === "select" ? Qt.ArrowCursor : Qt.CrossCursor

                property string activeId: ""
                property real ox: 0
                property real oy: 0

                function toShot(px, py) {
                    return Qt.point(px / viewport.fit - doc.geo.cardX,
                                    py / viewport.fit - doc.geo.cardY - doc.geo.chromeH);
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
            visible: !doc.hasShot
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
                text: "Grab a region, a window or the whole screen. OmaSnap adds the padding, background and shadow, and hides anything that should not be public."
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                lineHeight: 1.35
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Ui.gap
                IconButton { glyph: "\u2b1a"; label: "Capture a region"; onClicked: editor.captureRequested("region") }
                IconButton { glyph: "\u2026"; label: "Open a file"; onClicked: editor.openRequested() }
            }
        }
    }

    Inspector {
        id: inspector
        doc: editor.doc
        anchors { top: header.bottom; bottom: footer.top; right: parent.right }
        width: Style.space(300)
        visible: doc.hasShot
        onAutoRedactRequested: editor.autoRedactRequested()
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
            width: Math.min(implicitWidth, parent.width - Style.space(360))
            elide: Text.ElideRight
            text: editor.statusText !== "" ? editor.statusText
                  : doc.outputTooLarge ? "Too large to render at " + doc.exportScale + "\u00d7 \u2014 pick a smaller export scale"
                  : (doc.hasShot ? Math.round(viewport.fit * 100) + "%  \u00b7  "
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
            visible: doc.hasShot

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
                glyph: "\u2193"
                label: "Save"
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
