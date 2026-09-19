import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "tahayvr.omasnap"

    readonly property string icon: root.setting("icon", "󱓒")

    implicitWidth: button.implicitWidth
    implicitHeight: barSize

    // Prefer the in-process shell facade; the CLI round trip is only for a
    // bar host that did not hand us one.
    function summon(payload) {
        if (root.bar && root.bar.shell && typeof root.bar.shell.summon === "function") {
            root.bar.shell.summon(root.moduleName, payload);
            return;
        }
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.moduleName, payload]);
    }

    WidgetButton {
        id: button
        anchors.centerIn: parent
        bar: root.bar
        text: root.icon
        tooltipText: "OmaSnap: click to grab a region, right-click to open the editor"
        useActiveColor: false
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.LeftButton) root.summon('{"capture":"region"}');
            else if (mouseButton === Qt.RightButton) root.summon('{}');
        }
    }
}
