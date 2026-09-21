import QtQuick
import qs.Commons

// One row high, for the tool bar in the header. The inspector's
// LabeledSlider is two rows tall and fills the width of its column.
Item {
    id: root
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property string suffix: ""
    property int trackWidth: Style.space(90)
    signal moved(real value)

    implicitWidth: row.implicitWidth
    implicitHeight: Ui.button

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Ui.gap

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Ui.textMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }

        Item {
            id: track
            width: root.trackWidth
            height: Ui.button
            anchors.verticalCenter: parent.verticalCenter

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
                cursorShape: Qt.PointingHandCursor
                function apply(mx) {
                    var f = Math.max(0, Math.min(1, mx / track.width));
                    root.moved(root.from + f * (root.to - root.from));
                }
                onPressed: function (e) { apply(e.x); }
                onPositionChanged: function (e) { if (pressed) apply(e.x); }
            }
        }

        // Fixed width, so the row does not shift while the value changes.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(30)
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.value) + root.suffix
            color: Ui.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
    }
}
