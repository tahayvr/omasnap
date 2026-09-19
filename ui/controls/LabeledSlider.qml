import QtQuick
import qs.Commons

Item {
    id: root
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property int decimals: 0
    property string suffix: ""
    signal moved(real value)

    width: parent ? parent.width : 0
    implicitHeight: Style.space(40)

    function format(v) { return v.toFixed(root.decimals); }
    function clamp(v) { return Math.max(root.from, Math.min(root.to, v)); }

    Text {
        id: caption
        anchors.left: parent.left
        anchors.verticalCenter: field.verticalCenter
        text: root.label
        color: Ui.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }

    // The readout is also the input: click it and type a value, Return to
    // apply, Escape to abandon. Its width is fixed to the widest number the
    // range can produce so nothing shifts while dragging or typing.
    Rectangle {
        id: field
        anchors.right: parent.right
        anchors.top: parent.top
        width: entry.width + unit.width + Ui.gap * 2
        height: Style.space(20)
        color: entry.activeFocus ? Ui.fill : (hover.containsMouse ? Ui.fillHover : "transparent")
        border.width: entry.activeFocus ? 1 : 0
        border.color: Ui.borderActive

        TextMetrics {
            id: widest
            font: entry.font
            text: root.format(Math.max(Math.abs(root.from), Math.abs(root.to)))
        }

        // Below the input so a click inside the number still places the
        // cursor; this only catches the padding and the suffix.
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            onPressed: { entry.forceActiveFocus(); entry.selectAll(); }
        }

        TextInput {
            id: entry
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: unit.left
            width: Math.ceil(widest.width) + 2
            horizontalAlignment: TextInput.AlignRight
            text: root.format(root.value)
            color: entry.activeFocus ? Ui.text : Ui.textMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            selectByMouse: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator {
                bottom: root.from
                top: root.to
                decimals: root.decimals
                notation: DoubleValidator.StandardNotation
            }

            // Typing replaces the binding above; put it back once editing ends.
            function rebind() {
                entry.text = Qt.binding(function () { return root.format(root.value); });
            }
            function commit() {
                var v = parseFloat(entry.text);
                if (!isNaN(v)) root.moved(root.clamp(v));
                rebind();
            }

            onActiveFocusChanged: if (entry.activeFocus) entry.selectAll(); else entry.commit();
            Keys.onReturnPressed: { entry.commit(); entry.focus = false; }
            Keys.onEnterPressed: { entry.commit(); entry.focus = false; }
            Keys.onEscapePressed: { entry.rebind(); entry.focus = false; }
        }

        Text {
            id: unit
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Ui.gap
            text: root.suffix
            color: Ui.textMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Style.space(14)

        readonly property real norm: (root.to - root.from) === 0
            ? 0 : Math.max(0, Math.min(1, (root.value - root.from) / (root.to - root.from)))

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 2
            color: Ui.tint(0.16)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * track.norm
            height: 2
            color: Color.accent
        }
        Rectangle {
            x: track.norm * (track.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(12)
            height: width
            color: Color.accent
            scale: ma.pressed ? 1.2 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            cursorShape: Qt.PointingHandCursor
            // e.x is measured from the enlarged area, not the track.
            function apply(mx) {
                var f = Math.max(0, Math.min(1, (mx - Style.space(6)) / track.width));
                root.moved(root.from + f * (root.to - root.from));
            }
            onPressed: function (e) { entry.focus = false; apply(e.x); }
            onPositionChanged: function (e) { if (pressed) apply(e.x); }
        }
    }
}
