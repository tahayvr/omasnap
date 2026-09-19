pragma Singleton
import QtQuick

// Test stand-in for the shell's Style singleton: just the members the plugin reads.
QtObject {
    property int cornerRadius: 8
    property int gapsOut: 5
    function space(px) { return px; }
    function spaceReal(px) { return px; }
    readonly property QtObject font: QtObject {
        readonly property string family: "monospace"
        readonly property int caption: 10
        readonly property int bodySmall: 11
        readonly property int body: 12
        readonly property int subtitle: 13
        readonly property int title: 14
        readonly property int heading: 16
        readonly property int display: 24
        readonly property int iconSmall: 11
        readonly property int icon: 14
        readonly property int iconLarge: 18
    }
}
