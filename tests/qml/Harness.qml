import QtQuick
import "../../ui"
import "../../lib/Model.js" as Model

// Offscreen render of the stage with one of every annotation, exported the
// same way the overlay does it. tests/qml/render.sh checks the pixels.
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
        interactive: true
        scale: 0.5                       // displayed smaller, like the editor
        transformOrigin: Item.TopLeft
        // Same lookup as Overlay.qml: the window's effective ratio, not the screen's.
        readonly property real dpr: {
            var w = stage.Window.window;
            if (w && w.devicePixelRatio > 0) return w.devicePixelRatio;
            return Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1;
        }
    }

    Component.onCompleted: {
        doc.shotPath = win.outDir + "shot.png";
        doc.shotWidth = 400;
        doc.shotHeight = 200;
        doc.bgMode = "solid";
        doc.bgSolid = "#00ff00";
        doc.padding = 10;                // 10% of 400 = 40px each side
        doc.radius = 0;
        doc.shadow = 0;
        doc.frame = "none";
        doc.exportScale = 1;

        var box = Model.newAnnotation("box", 10, 10);
        box.w = 50; box.h = 50; box.color = "#0000ff"; box.width = 4;
        doc.addAnnotation(box);          // also selects it: the outline must not export

        var redact = Model.newAnnotation("redact", 150, 50);
        redact.w = 100; redact.h = 100; redact.strength = 25;
        doc.annotations.append(redact);

        var step = Model.newAnnotation("step", 300 - 18, 100 - 18);
        step.w = 36; step.h = 36; step.index = 7; step.color = "#ff0000";
        doc.annotations.append(step);

        var arrow = Model.newAnnotation("arrow", 320, 20);
        arrow.w = 60; arrow.h = 60; arrow.color = "#ff00ff"; arrow.width = 4;
        doc.annotations.append(arrow);

        var label = Model.newAnnotation("text", 20, 150);
        label.text = "Hello"; label.color = "#000000"; label.width = 4;
        doc.annotations.append(label);

        var empty = Model.newAnnotation("text", 20, 100);
        empty.text = ""; empty.color = "#000000"; empty.width = 4;
        doc.annotations.append(empty);   // placeholder must not export

        doc.annotationsEdited();
        grabTimer.start();
    }

    // grabToImage is asynchronous, so the two exports are chained rather than
    // fired together: the second one changes the geometry the first is using.
    function grab(name, done) {
        doc.exporting = true;
        Qt.callLater(function () {
            var size = Model.grabSize(doc.outWidth, doc.outHeight, stage.dpr);
            var ok = stage.grabToImage(function (r) {
                var wrote = r.saveToFile(win.outDir + name + ".png");
                console.warn("HARNESS " + name + " " + (wrote ? "ok" : "write-failed")
                             + " expected " + doc.outWidth + "x" + doc.outHeight
                             + " dpr " + stage.dpr);
                done();
            }, Qt.size(size.w, size.h));
            if (!ok) { console.warn("HARNESS grab-failed"); Qt.quit(); }
        });
    }

    Timer {
        id: grabTimer
        interval: 600
        onTriggered: win.grab("export", function () {
            // The inset extends the shot's edge colour: the left edge of this
            // synthetic shot is white, the right edge black.
            doc.shotEdge = "#ff00ff";
            doc.inset = 10;              // 10% of 400 = 40px on every side
            insetTimer.start();
        })
    }

    Timer {
        id: insetTimer
        interval: 250
        onTriggered: win.grab("export-inset", function () { Qt.quit(); })
    }
}
