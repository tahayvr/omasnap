import QtQuick
import qs.Commons

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    signal done()

    width: parent ? parent.width : 0
    height: Ui.control
    color: Ui.fill
    border.width: input.activeFocus ? 1 : 0
    border.color: Ui.borderActive

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Ui.padX
        anchors.rightMargin: Ui.padX
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Ui.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        selectByMouse: true
        Keys.onReturnPressed: root.done()
        Keys.onEnterPressed: root.done()
        Keys.onEscapePressed: root.done()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: root.placeholder
            color: Ui.textFaint
            font: input.font
        }
    }
}
