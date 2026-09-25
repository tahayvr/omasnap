import QtQuick
import qs.Commons

// Title bar. Omarchy windows carry no buttons, so this is the title alone.
Rectangle {
    id: chrome
    property string title: ""
    property real topRadius: 0
    property color textColor: Color.foreground

    width: parent ? parent.width : 0
    visible: height > 0
    topLeftRadius: topRadius
    topRightRadius: topRadius

    Text {
        anchors.centerIn: parent
        text: chrome.title
        color: chrome.textColor
        opacity: 0.8
        font.family: Style.font.family
        font.pixelSize: Math.round(chrome.height * 0.5)
        elide: Text.ElideMiddle
        width: parent.width * 0.7
        horizontalAlignment: Text.AlignHCenter
    }
}
