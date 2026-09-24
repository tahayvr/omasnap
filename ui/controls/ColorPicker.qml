import QtQuick
import qs.Commons
import "../../lib/Model.js" as Model

// Saturation and brightness on a square, hue on a bar, the hex as typed, and
// the eyedropper. It edits live while the pointer moves and says when a
// choice was actually made, so the caller can remember that one alone.
Column {
    id: root
    property string value: "#000000"
    property var recent: []

    signal edited(string hex)
    signal committed(string hex)
    signal eyedropRequested()
    signal forgotten(string hex)

    width: parent ? parent.width : 0
    spacing: Ui.row

    property real hue: 0
    property real sat: 0
    property real val: 0
    // What this picker last sent out. The value coming back round is that
    // same color, and re-reading it would snap the hue of a gray to red.
    property string sent: ""

    function sync() {
        var c = Model.normaliseHex(root.value);
        if (!c || c === root.sent) return;
        var hsv = Model.hexToHsv(c, root.hue);
        root.hue = hsv.h;
        root.sat = hsv.s;
        root.val = hsv.v;
        root.sent = c;
    }
    onValueChanged: sync()
    Component.onCompleted: sync()

    function send(commit) {
        var hex = Model.hsvToHex(root.hue, root.sat, root.val);
        root.sent = hex;
        root.edited(hex);
        if (commit) root.committed(hex);
    }

    function take(hex) {
        var c = Model.normaliseHex(hex);
        if (!c) return;
        var hsv = Model.hexToHsv(c, root.hue);
        root.hue = hsv.h;
        root.sat = hsv.s;
        root.val = hsv.v;
        root.sent = c;
        root.edited(c);
        root.committed(c);
    }

    Item {
        id: field
        width: parent.width
        height: Math.round(width * 0.62)

        Rectangle {
            anchors.fill: parent
            color: Model.hsvToHex(root.hue, 1, 1)
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#ffffffff" }
                GradientStop { position: 1; color: "#00ffffff" }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#00000000" }
                GradientStop { position: 1; color: "#ff000000" }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Ui.hairline
        }

        Rectangle {
            readonly property real size: Math.round(Ui.swatch * 0.55)
            width: size
            height: size
            x: root.sat * field.width - width / 2
            y: (1 - root.val) * field.height - height / 2
            color: "transparent"
            border.width: 2
            border.color: root.val > 0.6 && root.sat < 0.5 ? "#000000" : "#ffffff"
        }

        MouseArea {
            id: fieldArea
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            function at(x, y) {
                root.sat = Model.clamp(x / field.width, 0, 1);
                root.val = 1 - Model.clamp(y / field.height, 0, 1);
                root.send(false);
            }
            onPressed: function (e) { fieldArea.at(e.x, e.y); }
            onPositionChanged: function (e) { if (fieldArea.pressed) fieldArea.at(e.x, e.y); }
            onReleased: root.send(true)
        }
    }

    Item {
        id: hueBar
        width: parent.width
        height: Math.round(Ui.swatch * 0.6)

        Rectangle {
            anchors.fill: parent
            border.width: 1
            border.color: Ui.hairline
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0 / 6; color: "#ff0000" }
                GradientStop { position: 1 / 6; color: "#ffff00" }
                GradientStop { position: 2 / 6; color: "#00ff00" }
                GradientStop { position: 3 / 6; color: "#00ffff" }
                GradientStop { position: 4 / 6; color: "#0000ff" }
                GradientStop { position: 5 / 6; color: "#ff00ff" }
                GradientStop { position: 6 / 6; color: "#ff0000" }
            }
        }

        Rectangle {
            width: 4
            height: parent.height + 4
            y: -2
            x: root.hue / 360 * hueBar.width - width / 2
            color: "transparent"
            border.width: 2
            border.color: "#ffffff"
        }

        MouseArea {
            id: hueArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function at(x) {
                // Short of 360, which is red again and would read back as 0.
                root.hue = Model.clamp(x / hueBar.width, 0, 0.999) * 360;
                root.send(false);
            }
            onPressed: function (e) { hueArea.at(e.x); }
            onPositionChanged: function (e) { if (hueArea.pressed) hueArea.at(e.x); }
            onReleased: root.send(true)
        }
    }

    Row {
        width: parent.width
        spacing: Ui.gap

        Rectangle {
            width: Ui.control
            height: Ui.control
            color: Model.normaliseHex(root.value) || "transparent"
            border.width: 1
            border.color: Ui.hairline
        }

        TextBox {
            id: hex
            width: parent.width - Ui.control - eyedrop.width - Ui.gap * 2
            text: Model.normaliseHex(root.value)
            placeholder: "#rrggbb"
            onDone: {
                root.take(hex.text);
                // Typing broke the binding; put it back so the field keeps
                // following the color whatever was typed.
                hex.text = Qt.binding(function () { return Model.normaliseHex(root.value); });
            }
        }

        IconButton {
            id: eyedrop
            glyph: ""
            tip: "Pick a color from the screen"
            implicitHeight: Ui.control
            onClicked: root.eyedropRequested()
        }
    }

    Text {
        visible: root.recent.length > 0
        text: "Your colors"
        color: Ui.textMuted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }

    // Nine across like the inspector's swatches, sized to fill the row.
    Grid {
        width: parent.width
        spacing: Ui.gap
        columns: 9
        visible: root.recent.length > 0
        Repeater {
            model: root.recent
            UserSwatch {
                required property var modelData
                width: (root.width - Ui.gap * 8) / 9
                height: width
                swatchColor: modelData
                active: Model.normaliseHex(root.value) === Model.normaliseHex(modelData)
                onPicked: root.take(modelData)
                onRemoved: root.forgotten(modelData)
            }
        }
    }
}
