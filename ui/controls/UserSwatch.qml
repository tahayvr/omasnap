import QtQuick
import qs.Commons
import "../../lib/Model.js" as Model

// One of the user's own colors, or with `stops` one of their gradients, with
// a corner button to forget it. The hover is a handler on the whole thing
// rather than the swatch's own area, so moving onto the button does not hide
// it.
Item {
    id: root
    property color swatchColor: "#ffffff"
    property var stops: []
    property bool active: false
    signal picked()
    signal removed()

    readonly property bool isGradient: root.stops.length > 0
    width: root.isGradient ? Ui.tile : Ui.swatch
    height: Ui.swatch

    HoverHandler { id: hover }

    Swatch {
        visible: !root.isGradient
        swatchColor: root.swatchColor
        active: root.active
        onPicked: root.picked()
    }

    // Addressed by id: a GradientStop's parent is not the Rectangle.
    Rectangle {
        id: ramp
        visible: root.isGradient
        anchors.fill: parent
        readonly property var slots: Model.gradientStops(root.isGradient ? root.stops : ["#000000"])
        border.width: root.active ? 2 : (rampArea.containsMouse ? 1 : 0)
        border.color: root.active ? Color.foreground : Ui.textMuted
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: ramp.slots[0].at; color: ramp.slots[0].color }
            GradientStop { position: ramp.slots[1].at; color: ramp.slots[1].color }
            GradientStop { position: ramp.slots[2].at; color: ramp.slots[2].color }
            GradientStop { position: ramp.slots[3].at; color: ramp.slots[3].color }
            GradientStop { position: ramp.slots[4].at; color: ramp.slots[4].color }
        }
        MouseArea {
            id: rampArea
            anchors.fill: parent
            enabled: root.isGradient
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked()
        }
    }

    Rectangle {
        id: badge
        readonly property int size: Math.round(Ui.swatch * 0.5)
        width: size
        height: size
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -Math.round(size / 3)
        anchors.rightMargin: -Math.round(size / 3)
        visible: hover.hovered
        color: badgeArea.containsMouse ? Color.foreground : Color.background
        border.width: 1
        border.color: Ui.textMuted

        Text {
            anchors.centerIn: parent
            text: "×"
            color: badgeArea.containsMouse ? Color.background : Ui.text
            font.family: Style.font.family
            font.pixelSize: Math.round(badge.size * 0.8)
        }

        MouseArea {
            id: badgeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removed()
        }

        Tooltip {
            target: badge
            text: root.isGradient ? "Remove this gradient" : "Remove this color"
            show: badgeArea.containsMouse
        }
    }
}
