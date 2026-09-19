import QtQuick
import qs.Commons

Column {
    id: root
    property string title: ""
    default property alias content: holder.data
    width: parent ? parent.width : 0
    spacing: Ui.row

    Text {
        text: root.title
        visible: root.title !== ""
        color: Ui.textMuted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1
    }

    Column {
        id: holder
        width: parent.width
        spacing: Ui.row
    }
}
