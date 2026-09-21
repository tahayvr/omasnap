import QtQuick
import qs.Commons
import "controls"

Item {
    id: rail
    property var doc
    signal status(string text)

    readonly property int annotationCount: rail.doc ? rail.doc.annotations.count : 0

    readonly property var tools: [
        { key: "select",    glyph: "↖", name: "Move",      hint: "V" },
        { key: "arrow",     glyph: "↗", name: "Arrow",     hint: "A" },
        { key: "box",       glyph: "□", name: "Box",       hint: "R" },
        { key: "ellipse",   glyph: "○", name: "Ellipse",   hint: "O" },
        { key: "text",      glyph: "T",      name: "Text",      hint: "T" },
        { key: "step",      glyph: "①", name: "Step",      hint: "S" },
        { key: "highlight", glyph: "▤", name: "Highlight", hint: "H" },
        { key: "redact",    glyph: "░", name: "Hide",      hint: "B" },
        { key: "spotlight", glyph: "◎", name: "Spotlight", hint: "L" },
        { key: "crop",      glyph: "\uf125", name: "Crop",  hint: "C", shotOnly: true }
    ]

    // A code card is drawn from its text, so there is nothing to cut down.
    readonly property var offered: rail.tools.filter(function (t) {
        return !t.shotOnly || (rail.doc && rail.doc.kind === "shot");
    })

    implicitWidth: Ui.button + Ui.row * 2

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Ui.row
        spacing: Ui.gap

        Repeater {
            model: rail.offered
            IconButton {
                required property var modelData
                glyph: modelData.glyph
                active: rail.doc.tool === modelData.key
                tip: modelData.name
                onClicked: {
                    rail.doc.tool = modelData.key;
                    rail.doc.selectedId = "";
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 3
                    text: parent.modelData.hint
                    color: Ui.textFaint
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption * 0.8
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Ui.row
        spacing: Ui.gap

        // Both are no-ops on an unannotated shot, so they say so instead of
        // looking like a button that does nothing.
        IconButton {
            glyph: "↶"
            flat: true
            enabled: rail.annotationCount > 0
            tip: "Undo (Ctrl+Z)"
            onClicked: {
                rail.doc.undo();
                rail.status("Undid the last annotation");
            }
        }
        IconButton {
            glyph: "✕"
            flat: true
            enabled: rail.annotationCount > 0
            tip: "Clear every annotation"
            onClicked: {
                var n = rail.annotationCount;
                rail.doc.clearAnnotations();
                rail.status("Cleared " + n + (n === 1 ? " annotation" : " annotations"));
            }
        }
    }
}
