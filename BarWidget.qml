import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "tahayvr.omasnap"

    readonly property string icon: root.setting("icon", "󱥚")

    implicitWidth: button.implicitWidth
    implicitHeight: barSize

    function summon(payload) {
        root.bar.shell.summon(root.moduleName, payload);
    }

    WidgetButton {
        id: button
        anchors.centerIn: parent
        bar: root.bar
        text: root.icon
        tooltipText: "OmaSnap: click to grab a region, middle-click for a code card, right-click to open the editor"
        useActiveColor: false
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.LeftButton) root.summon('{"capture":"region"}');
            else if (mouseButton === Qt.MiddleButton) root.summon('{"code":true}');
            else if (mouseButton === Qt.RightButton) root.summon('{}');
        }
    }
}
