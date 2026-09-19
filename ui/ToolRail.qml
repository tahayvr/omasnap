import QtQuick
import qs.Commons
import "controls"

Item {
    id: rail
    property var doc

    readonly property var tools: [
        { key: "select",    glyph: "↖", name: "Move",      hint: "V" },
        { key: "arrow",     glyph: "↗", name: "Arrow",     hint: "A" },
        { key: "box",       glyph: "□", name: "Box",       hint: "R" },
        { key: "ellipse",   glyph: "○", name: "Ellipse",   hint: "O" },
        { key: "text",      glyph: "T",      name: "Text",      hint: "T" },
        { key: "step",      glyph: "①", name: "Step",      hint: "S" },
        { key: "highlight", glyph: "▤", name: "Highlight", hint: "H" },
        { key: "redact",    glyph: "░", name: "Hide",      hint: "B" }
    ]

    implicitWidth: Ui.button + Ui.row * 2

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Ui.row
        spacing: Ui.gap

        Repeater {
            model: rail.tools
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

        IconButton {
            glyph: "↶"
            flat: true
            tip: "Undo"
            onClicked: rail.doc.undo()
        }
        IconButton {
            glyph: "✕"
            flat: true
            tip: "Clear annotations"
            onClicked: rail.doc.clearAnnotations()
        }
    }
}
