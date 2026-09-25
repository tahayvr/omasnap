import QtQuick
import qs.Commons

Rectangle {
    id: root
    property string glyph: ""
    property string label: ""
    property bool active: false
    property bool flat: false
    property bool primary: false
    property string tip: ""
    property color rest: flat ? "transparent" : Ui.fill
    signal clicked()
    signal pressStarted()
    readonly property bool held: ma.pressed

    implicitWidth: label !== "" ? row.implicitWidth + Ui.padX * 2 : Ui.button
    implicitHeight: Ui.button
    color: primary ? (ma.containsMouse ? Qt.lighter(Color.accent, 1.12) : Color.accent)
         : active ? Ui.fillActive
         : ma.containsMouse ? Ui.fillHover
         : rest
    border.width: active ? 1 : 0
    border.color: Ui.borderActive
    Behavior on color { ColorAnimation { duration: 90 } }

    readonly property color ink: primary ? Color.background : active ? Color.accent : Ui.text

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Ui.gap

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            visible: root.glyph !== ""
            color: root.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            visible: root.label !== ""
            color: root.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: root.primary
        }
    }

    opacity: root.enabled ? 1 : 0.35

    Tooltip {
        target: root
        text: root.tip
        show: hold.running === false && ma.containsMouse && !ma.pressed && root.tip !== ""
    }

    // A tooltip that appears the instant the pointer crosses the button is
    // noise while the pointer is only passing through the rail.
    Timer {
        id: hold
        interval: 350
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: hold.restart()
        onExited: hold.stop()
        onPressed: root.pressStarted()
        onClicked: root.clicked()
    }
}
