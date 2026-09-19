import QtQuick
import "../../ui"
import "../../lib/Code.js" as Code

// GPU render of a code document through the same Stage the overlay uses.
Window {
    id: win
    visible: true
    width: 640
    height: 480

    readonly property string outDir: Qt.resolvedUrl("out/").toString().replace(/^file:\/\//, "")

    Doc { id: doc }

    Stage {
        id: stage
        doc: doc
        scale: 0.5
        transformOrigin: Item.TopLeft
        readonly property real dpr: {
            var w = stage.Window.window;
            if (w && w.devicePixelRatio > 0) return w.devicePixelRatio;
            return Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1;
        }
    }

    Component.onCompleted: {
        doc.kind = "code";
        doc.bgMode = "solid";
        doc.bgSolid = "#00ff00";
        doc.padding = 10;
        doc.radius = 0;
        doc.shadow = 0;
        doc.exportScale = 1;
        doc.codeBg = "#202030";
        doc.codeFg = "#ffffff";
        doc.codeFont = 16;
        doc.codeText = "fn main() {\n    let x = 1;\n}";
        doc.codeHtml = Code.ansiToHtml("\x1b[38;2;255;0;0mfn\x1b[0m main() {\n    let x = 1;\n}", Code.defaultPalette("#ffffff"));
        grabTimer.start();
    }

    Timer {
        id: grabTimer
        interval: 600
        onTriggered: {
            console.warn("HARNESS shot " + doc.shotWidth + "x" + doc.shotHeight + " frame " + doc.outWidth + "x" + doc.outHeight);
            doc.exporting = true;
            Qt.callLater(function () {
                var s = grabSize();
                stage.grabToImage(function (r) {
                    r.saveToFile(win.outDir + "export-code.png");
                    console.warn("HARNESS ok");
                    Qt.quit();
                }, Qt.size(s.w, s.h));
            });
        }
    }
    function grabSize() {
        var d = stage.dpr;
        return { w: Math.max(1, Math.round(doc.outWidth / d)), h: Math.max(1, Math.round(doc.outHeight / d)) };
    }
}
