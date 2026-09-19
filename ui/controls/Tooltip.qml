import QtQuick
import qs.Commons

// Hover label for a control. It reparents itself to the window's content item
// so it draws over the panels either side of it: a tooltip left inside the
// tool rail would be painted under the viewport, which is a later sibling.
Rectangle {
    id: tip
    property Item target: null
    property string text: ""
    property bool show: false

    parent: tip.target && tip.target.Window.window
            ? tip.target.Window.window.contentItem : null

    z: 1000
    width: label.implicitWidth + Ui.padX * 2
    height: Ui.control
    visible: tip.show && tip.text !== "" && tip.parent !== null
    opacity: tip.visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 90 } }

    color: Color.tooltip && Color.tooltip.background ? Color.tooltip.background : Color.background
    border.width: 1
    border.color: Color.tooltip && Color.tooltip.border ? Color.tooltip.border : Ui.hairline

    Text {
        id: label
        anchors.centerIn: parent
        text: tip.text
        color: Color.tooltip && Color.tooltip.text ? Color.tooltip.text : Ui.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }

    // mapToItem is a one-off calculation, so the position is taken when the
    // tooltip appears rather than bound; the target does not move under it.
    function place() {
        if (!tip.target || !tip.parent) return;
        var right = tip.target.mapToItem(tip.parent, tip.target.width, tip.target.height / 2);
        var left = tip.target.mapToItem(tip.parent, 0, 0);

        // The content item can still report no size while a window is being
        // set up; flipping or clamping against that would park the tooltip in
        // the corner, so only do it once there is a width to respect.
        var x = right.x + Ui.gap;
        if (tip.parent.width > 0 && x + tip.width > tip.parent.width - Ui.gap)
            x = left.x - tip.width - Ui.gap;
        tip.x = Math.max(Ui.gap, x);

        var y = right.y - tip.height / 2;
        if (tip.parent.height > 0)
            y = Math.min(tip.parent.height - tip.height - Ui.gap, y);
        tip.y = Math.max(Ui.gap, y);
    }

    onShowChanged: if (tip.show) tip.place()
    onWidthChanged: if (tip.show) tip.place()
}
