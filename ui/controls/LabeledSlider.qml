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
    implicitHeight: Style.space(36)

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: Ui.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.value.toFixed(root.decimals) + root.suffix
        color: Ui.textMuted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
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
            onPressed: function (e) { apply(e.x); }
            onPositionChanged: function (e) { if (pressed) apply(e.x); }
        }
    }
}
