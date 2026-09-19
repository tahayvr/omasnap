import QtQuick
import qs.Commons

// A toggleable label, for multi-select choices.
Rectangle {
    id: root
    property string label: ""
    property bool on: false
    signal toggled()

    implicitWidth: t.implicitWidth + Ui.padX * 2
    height: Ui.control
    color: on ? Ui.fillActive : m.containsMouse ? Ui.fillHover : Ui.fill
    border.width: on ? 1 : 0
    border.color: Ui.borderActive
    Behavior on color { ColorAnimation { duration: 90 } }

    Text {
        id: t
        anchors.centerIn: parent
        text: root.label
        color: root.on ? Color.accent : Ui.textMuted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
