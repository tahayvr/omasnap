import QtQuick
import qs.Commons

// The code card's contents, sized by the text plus padding. Reports its
// natural size through measured() so the document can adopt it.
Item {
    id: block
    property var doc: null
    signal measured(int w, int h)

    // Qt hangs the proportional line spacing below every line, the last one
    // included, so the measured text is taller than it looks and the card
    // ends up with visibly more room under the code than over it. Take that
    // trailing leading back off.
    readonly property real lineBox: label.lineCount > 0
                                    ? label.implicitHeight / label.lineCount : 0
    readonly property real trailing: lineBox * (1 - 1 / label.lineHeight)

    readonly property int naturalW: Math.ceil(label.implicitWidth + doc.codePad * 2)
    readonly property int naturalH: Math.ceil(label.implicitHeight - trailing + doc.codePad * 2)

    width: naturalW
    height: naturalH

    onNaturalWChanged: block.measured(naturalW, naturalH)
    onNaturalHChanged: block.measured(naturalW, naturalH)

    Text {
        id: label
        x: block.doc.codePad
        y: block.doc.codePad
        textFormat: Text.StyledText
        text: block.doc.codeHtml
        color: block.doc.codeFg
        font.family: Style.font.family
        font.pixelSize: block.doc.codeFont
        lineHeight: 1.45
    }
}
