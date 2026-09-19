import QtQuick
import qs.Commons

// One strip of options; [{key, label}].
Flow {
    id: root
    property var options: []
    property string current: ""
    property int minWidth: 0
    signal picked(string key)

    width: parent ? parent.width : 0
    spacing: Ui.gap

    Repeater {
        model: root.options
        Rectangle {
            required property var modelData
            readonly property bool on: root.current === modelData.key

            implicitWidth: Math.max(root.minWidth, t.implicitWidth + Ui.padX * 2)
            height: Ui.control
            color: on ? Ui.fillActive : m.containsMouse ? Ui.fillHover : Ui.fill
            border.width: on ? 1 : 0
            border.color: Ui.borderActive
            Behavior on color { ColorAnimation { duration: 90 } }

            Text {
                id: t
                anchors.centerIn: parent
                text: modelData.label
                color: parent.on ? Color.accent : Ui.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(modelData.key)
            }
        }
    }
}
