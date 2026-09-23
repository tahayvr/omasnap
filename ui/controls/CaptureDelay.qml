pragma Singleton
import QtQuick

// The overlay and the bar widget are separate trees with no call between
// them, but they share one engine and both import this directory, so this
// is the one object both can see: the bar picks the delay the editor uses,
// and shows the countdown the overlay runs.
QtObject {
    readonly property var choices: [0, 3, 5, 10]

    property int seconds: 0
    property int remaining: 0

    function cycle() {
        seconds = choices[(choices.indexOf(seconds) + 1) % choices.length];
    }

    function label(n) {
        return n ? n + "s" : "Now";
    }
}
