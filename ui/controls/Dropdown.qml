import QtQuick
import QtQuick.Controls as QQC
import qs.Commons

// Single-select dropdown; options are [{key, label}].
Item {
    id: root
    property var options: []
    property string current: ""
    property int visibleRows: 8
    signal picked(string key)

    readonly property string currentLabel: {
        for (var i = 0; i < options.length; i++)
            if (options[i].key === current) return options[i].label;
        return current;
    }

    width: parent ? parent.width : 0
    implicitHeight: Ui.control

    Rectangle {
        id: trigger
        anchors.fill: parent
        color: popup.opened ? Ui.fillActive : ma.containsMouse ? Ui.fillHover : Ui.fill
        border.width: popup.opened ? 1 : 0
        border.color: Ui.borderActive
        Behavior on color { ColorAnimation { duration: 90 } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Ui.padX
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel
            elide: Text.ElideRight
            color: popup.opened ? Color.accent : Ui.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: Ui.padX
            anchors.verticalCenter: parent.verticalCenter
            text: popup.opened ? "▴" : "▾"
            color: Ui.textMuted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.opened ? popup.close() : popup.open()
        }
    }

    QQC.Popup {
        id: popup
        y: root.height + 2
        width: root.width
        height: Math.min(root.options.length, root.visibleRows) * Ui.control + 2
        padding: 1
        focus: true
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside

        background: Rectangle {
            color: Color.menu && Color.menu.background ? Color.menu.background : Color.background
            border.width: 1
            border.color: Ui.borderActive
        }

        onOpened: {
            list.currentIndex = Math.max(0, list.indexOfKey(root.current));
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            list.forceActiveFocus();
        }

        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: -1
            highlightFollowsCurrentItem: true

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape) { popup.close(); event.accepted = true; }
                else if (event.key === Qt.Key_Down) { currentIndex = Math.min(count - 1, currentIndex + 1); event.accepted = true; }
                else if (event.key === Qt.Key_Up) { currentIndex = Math.max(0, currentIndex - 1); event.accepted = true; }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (currentIndex >= 0) root.picked(root.options[currentIndex].key);
                    popup.close();
                    event.accepted = true;
                }
            }

            function indexOfKey(key) {
                for (var i = 0; i < root.options.length; i++) if (root.options[i].key === key) return i;
                return -1;
            }

            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: modelData.key === root.current
                width: list.width
                height: Ui.control
                color: on ? Ui.fillActive : (rowMa.containsMouse || list.currentIndex === index) ? Ui.fillHover : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Ui.padX
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.label
                    color: parent.on ? Color.accent : Ui.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.picked(parent.modelData.key); popup.close(); }
                }
            }
        }
    }
}
