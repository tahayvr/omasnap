pragma Singleton
import QtQuick
import qs.Commons

// Metrics and tints shared by every piece of editor chrome.
QtObject {
    readonly property int control: Style.space(28)      // inspector controls
    readonly property int button: Style.space(32)       // header, footer, tool buttons
    readonly property int swatch: Style.space(24)
    readonly property int tile: Style.space(40)         // gradient tile width
    readonly property int gap: Style.space(6)           // between siblings
    readonly property int row: Style.space(10)          // between rows in a section
    readonly property int section: Style.space(22)      // between sections
    readonly property int pad: Style.space(16)          // panel padding
    readonly property int padX: Style.space(12)         // text inset inside a control

    readonly property color hairline: tint(0.12)
    readonly property color fill: tint(0.06)
    readonly property color fillHover: tint(0.11)
    readonly property color fillActive: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
    readonly property color borderActive: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.6)
    readonly property color text: Color.foreground
    readonly property color textMuted: tint(0.55)
    readonly property color textFaint: tint(0.35)

    function tint(alpha) {
        return Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, alpha);
    }
}
