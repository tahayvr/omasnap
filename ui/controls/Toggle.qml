import QtQuick
import qs.Commons

Item {
    id: root
    property string label: ""
    property string hint: ""
    property bool checked: false
    signal toggled(bool value)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(sw.height, caption.implicitHeight)

    // The hint is a tooltip rather than a second line: it explains a setting
    // that is already named, and a paragraph under every switch is the kind
    // of thing that makes a panel feel heavy.
    Text {
        id: caption
        anchors.left: parent.left
        anchors.right: sw.left
        anchors.rightMargin: Ui.row
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: Ui.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }

    Tooltip {
        target: root
        text: root.hint
        show: !hold.running && ma.containsMouse
    }

    Timer {
        id: hold
        interval: 350
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
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hold.restart()
        onExited: hold.stop()
        onClicked: root.toggled(!root.checked)
    }
}
