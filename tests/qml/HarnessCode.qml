import QtQuick
import "../../ui"
import "../../lib/Code.js" as Code
import "../../lib/Model.js" as Model

// GPU render of a code document through the same Stage the overlay uses.
Window {
    id: win
    visible: true
    width: 640
    height: 480

    // render.sh passes the output directory as the last argument: a file
    // written under the plugin directory reloads the plugin in the running
    // shell, and a full test run writes seven of them.
    readonly property string outDir: {
        var a = Qt.application.arguments;
        var last = a.length ? String(a[a.length - 1]) : "";
        if (last.charAt(0) !== "/") return "/tmp/postcard-tests/";
        return last.charAt(last.length - 1) === "/" ? last : last + "/";
    }

    Doc { id: doc }

    Item {
        id: grabRoot
        readonly property var fit: Model.grabSize(stage.width, stage.height, stage.dpr)
        width: grabRoot.fit.w
        height: grabRoot.fit.h
        scale: 0.5
        transformOrigin: Item.TopLeft

        Stage {
            id: stage
            doc: doc
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
            // Rendering the same snippet again must not blank the card: the
            // size is bound to CodeBlock, not pushed on a change signal.
            var was = doc.shotWidth;
            doc.codeHtml = "";
            doc.codeHtml = Code.ansiToHtml("\x1b[38;2;255;0;0mfn\x1b[0m main() {\n    let x = 1;\n}", Code.defaultPalette("#ffffff"));
            console.warn("HARNESS resize " + (doc.shotWidth === was && was > 0 ? "ok" : "FAIL")
                         + " same snippet measures " + doc.shotWidth + " (was " + was + ")");
            console.warn("HARNESS shot " + doc.shotWidth + "x" + doc.shotHeight + " frame " + doc.outWidth + "x" + doc.outHeight);
            doc.exporting = true;
            Qt.callLater(function () {
                grabRoot.grabToImage(function (r) {
                    r.saveToFile(win.outDir + "export-code.png");
                    console.warn("HARNESS ok expected " + doc.outWidth + "x" + doc.outHeight);
                    Qt.quit();
                }, Qt.size(grabRoot.width, grabRoot.height));
            });
        }
    }
}
