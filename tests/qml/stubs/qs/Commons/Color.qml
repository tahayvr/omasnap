pragma Singleton
import QtQuick

// Test stand-in for the shell's Color singleton.
QtObject {
    property color foreground: "#cacccc"
    property color background: "#101315"
    property color accent: "#88c0d0"
    property color urgent: "#a55555"
    readonly property QtObject menu: QtObject {
        property color background: "#101315"
        property color text: "#cacccc"
        property color border: "#cacccc"
        property color scrim: "#80101315"
    }
}
