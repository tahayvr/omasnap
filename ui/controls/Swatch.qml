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
    border.width: active || ma.containsMouse ? 2 : 1
    border.color: active ? Color.foreground
                : ma.containsMouse ? Ui.textMuted
                : Ui.hairline

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
