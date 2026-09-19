import QtQuick
import qs.Commons

Rectangle {
    id: root
    property color swatchColor: "#ffffff"
    property bool active: false
    signal picked()

    width: Ui.swatch
    height: Ui.swatch
    color: swatchColor
    border.width: active ? 2 : (ma.containsMouse ? 1 : 0)
    border.color: active ? Color.foreground : Ui.textMuted

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
