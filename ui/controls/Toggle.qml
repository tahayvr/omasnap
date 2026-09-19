import QtQuick
import qs.Commons

Item {
    id: root
    property string label: ""
    property string hint: ""
    property bool checked: false
    signal toggled(bool value)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(sw.height, col.implicitHeight)

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: sw.left
        anchors.rightMargin: Ui.row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.label
            color: Ui.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Text {
            text: root.hint
            visible: root.hint !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            color: Ui.textMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }

    Rectangle {
        id: sw
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(36)
        height: Style.space(20)
        color: root.checked ? Color.accent : Ui.tint(0.18)
        Behavior on color { ColorAnimation { duration: 110 } }

        Rectangle {
            width: parent.height - 6
            height: width
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: Color.background
            Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
