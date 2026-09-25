import QtQuick
import qs.Commons
import "controls"

// How Postcard behaves, as against how the card looks: nothing here is part
// of a preset, and it is kept on disk by the overlay (settings.json).
Item {
    id: prefs
    property var doc
    property string saveDir: ""

    Column {
        x: Ui.pad
        y: Ui.pad
        width: prefs.width - Ui.pad * 2
        spacing: Ui.section

        Section {
            title: "Saving"

            Toggle {
                label: "Copy to the clipboard when saving"
                hint: "Save also puts the picture on the clipboard"
                checked: prefs.doc.saveCopies
                onToggled: function (v) { prefs.doc.saveCopies = v; }
            }

            Text {
                width: parent.width
                text: "Saved to " + prefs.saveDir
                wrapMode: Text.WrapAnywhere
                color: Ui.textMuted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
    }
}
