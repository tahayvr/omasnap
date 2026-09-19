import QtQuick
import qs.Commons

// Window chrome: traffic lights and an optional centred title.
Rectangle {
    id: chrome
    property var doc: null
    property real topRadius: 0

    width: parent ? parent.width : 0
    visible: height > 0
    topLeftRadius: topRadius
    topRightRadius: topRadius

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: parent.height * 0.45
        spacing: parent.height * 0.26
        Repeater {
            model: ["#ff5f56", "#ffbd2e", "#27c93f"]
            Rectangle {
                required property string modelData
                width: chrome.height * 0.26
                height: width
                radius: width / 2
                color: modelData
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: chrome.doc.frame === "titlebar"
        text: chrome.doc.frameTitle
        color: Color.foreground
        opacity: 0.75
        font.family: Style.font.family
        font.pixelSize: chrome.height * 0.42
        elide: Text.ElideMiddle
        width: parent.width * 0.55
        horizontalAlignment: Text.AlignHCenter
    }
}
