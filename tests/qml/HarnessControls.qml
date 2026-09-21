import QtQuick
import QtQuick.Window
import "../../ui"
import "../../ui/controls"
import "../../lib/Model.js" as Model

// Editor controls that cannot be checked by looking at an exported image:
// LabeledSlider's readout is an editable field, so its text binding is broken
// the moment anyone types into it, and IconButton's tooltip has to reparent
// itself out of the button to be drawn at all. tests/qml/render.sh greps the
// output of this harness.
Window {
    id: win
    visible: true
    width: 400
    height: 300

    property real model: 5

    Doc { id: doc }

    // Off to the side; only its gradient swatches and toggles are under test.
    Inspector { id: inspector; doc: doc; x: 1000; width: 300; height: 800 }

    Toggle {
        id: toggle
        x: 1400
        width: 200
        label: "Optical balance"
        hint: "Lifts the shot slightly"
    }

    function meshLayer(item) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i];
            if (c.hasOwnProperty("base") && c.hasOwnProperty("points")) return c;
        }
        return null;
    }

    function swatches(item, out) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i];
            if (c.hasOwnProperty("stops") && c.hasOwnProperty("mesh")
                && c.hasOwnProperty("modelData")) out.push(c);
            win.swatches(c, out);
        }
        return out;
    }

    // The editor itself, for the drawing surface alone: its move handler is
    // called by hand below, since a harness has no pointer to push around.
    Editor { id: editor; doc: doc; x: 3000; width: 900; height: 600 }

    // Off to the side as well: its handles are driven by hand below, since a
    // harness has no pointer to push around.
    CropOverlay {
        id: cropper
        doc: doc
        viewScale: 1
        x: 2000
        width: 400
        height: 200
    }

    // The annotation layer proper, so the handles on a selected mark can be
    // found in the tree and read off: there is no pointer here to grab one.
    AnnotationLayer {
        id: marks
        doc: doc
        interactive: true
        viewScale: 1
        x: 4000
        width: 400
        height: 200
    }

    function entries(item, out) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i];
            if (typeof c.commit === "function" && typeof c.rebind === "function") out.push(c);
            win.entries(c, out);
        }
        return out;
    }

    function knobs(item, out) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i];
            if (c.hasOwnProperty("spot") && c.visible) out.push(c);
            win.knobs(c, out);
        }
        return out;
    }

    function rectText(r) {
        return Math.round(r.x) + "," + Math.round(r.y) + " "
             + Math.round(r.width) + "x" + Math.round(r.height);
    }

    IconButton {
        id: button
        x: 20
        y: 200
        glyph: "\u21b6"
        tip: "Undo"
    }

    Tooltip {
        id: loose
        target: button
        text: "Undo"
    }

    LabeledSlider {
        id: slider
        label: "Padding"
        value: win.model
        from: 0; to: 30; decimals: 1; suffix: "%"
        onMoved: function (v) { win.model = v; }
    }

    // The field is private to the control, so reach it by shape.
    function findInput(item) {
        for (var i = 0; i < item.children.length; i++) {
            var c = item.children[i];
            if (c.hasOwnProperty("validator") && typeof c.commit === "function") return c;
            var deep = findInput(c);
            if (deep) return deep;
        }
        return null;
    }

    function check(name, got, want) {
        console.warn((String(got) === String(want) ? "ok   " : "FAIL ")
                     + name + ": got " + got + " want " + want);
    }

    Component.onCompleted: Qt.callLater(function () {
        var e = win.findInput(slider);
        if (!e) { console.warn("FAIL could not reach the slider's input"); Qt.quit(); return; }

        win.check("readout shows the bound value", e.text, "5.0");

        e.text = "12.5"; e.commit();
        win.check("typed value applied", win.model, 12.5);
        win.check("readout followed", e.text, "12.5");

        e.text = "99"; e.commit();
        win.check("above range clamped", win.model, 30);
        win.check("readout shows the clamp", e.text, "30.0");

        e.text = "-4"; e.commit();
        win.check("below range clamped", win.model, 0);

        e.text = ""; e.commit();
        win.check("empty entry keeps the value", win.model, 0);
        win.check("empty entry restores the text", e.text, "0.0");

        e.text = "abc"; e.commit();
        win.check("junk keeps the value", win.model, 0);

        // The binding has been broken and restored several times by now; the
        // slider still has to drive the readout.
        win.model = 7.25;
        win.check("readout tracks the slider again", e.text, "7.3");

        e.text = "3"; e.rebind();
        win.check("escape abandons the edit", e.text, "7.3");
        win.check("escape leaves the value alone", win.model, 7.25);

        // A tooltip left inside its button would be painted under whatever
        // panel sits next to it, so it has to end up on the content item.
        win.check("tooltip escapes its target", loose.parent === win.contentItem, true);
        win.check("tooltip starts hidden", loose.visible, false);
        loose.show = true;
        win.check("tooltip shows", loose.visible, true);
        win.check("tooltip sits beside the button",
                  loose.x >= button.x + button.width, true);
        win.check("tooltip stays inside the window",
                  loose.x + loose.width <= win.width && loose.y >= 0
                  && loose.y + loose.height <= win.height, true);
        loose.show = false;
        win.check("tooltip hides again", loose.visible, false);

        // The button's own tooltip has reparented itself too, so look for it
        // among the content item's children rather than the button's.
        var own = null;
        var siblings = win.contentItem.children;
        for (var i = 0; i < siblings.length; i++)
            if (siblings[i] !== loose && siblings[i].hasOwnProperty("target")
                && siblings[i].target === button) own = siblings[i];
        win.check("IconButton carries a tooltip", own !== null, true);
        if (own) win.check("tooltip text follows tip", own.text, button.tip);

        // Qt's image cache is keyed on the URL, so reopening a file that
        // changed under the same path used to hand back the previous
        // picture. Every load has to produce a URL the cache has not seen.
        doc.shotPath = "/tmp/omasnap-example.png";
        var first = String(doc.shotUrl);
        win.check("shot url carries a revision", first.indexOf("#v") > 0, true);
        doc.shotRevision += 1;
        win.check("reloading the same path changes the url",
                  String(doc.shotUrl) !== first, true);
        win.check("and still points at the file",
                  String(doc.shotUrl).indexOf("/tmp/omasnap-example.png") > 0, true);

        // A toggle explains itself in a tooltip rather than a second line, so
        // it has to carry one wired to its hint, and must not draw the hint
        // as text: a paragraph under every switch is what this replaced.
        var tip = null, extra = 0;
        for (var t = 0; t < win.contentItem.children.length; t++) {
            var c = win.contentItem.children[t];
            if (c.hasOwnProperty("target") && c.target === toggle) tip = c;
        }
        win.check("a toggle carries a tooltip", tip !== null, true);
        if (tip) win.check("wired to its hint", tip.text, toggle.hint);
        function texts(item, out) {
            for (var i = 0; i < item.children.length; i++) {
                var k = item.children[i];
                if (k.hasOwnProperty("text") && !k.hasOwnProperty("target")) out.push(String(k.text));
                texts(k, out);
            }
            return out;
        }
        win.check("and does not also print it", texts(toggle, []).indexOf(toggle.hint), -1);

        // The inspector previews each preset with the same stop list the stage
        // uses. A GradientStop's `parent` is not the swatch, and writing it
        // that way rendered every swatch black, which nothing else would catch.
        doc.bgMode = "gradient";
        var sw = win.swatches(inspector, []);
        win.check("a swatch per preset", sw.length, Model.GRADIENTS.length);
        var ramps = sw.filter(function (s) { return !s.mesh; });
        var bad = ramps.filter(function (s) {
            var want = Model.gradientStops(s.modelData.stops);
            return s.gradient.stops.length !== Model.GRADIENT_STOPS
                || String(s.gradient.stops[0].color) !== want[0].color
                || String(s.gradient.stops[1].color) !== want[1].color;
        });
        win.check("every ramp swatch shows its own colors", bad.length, 0);
        var aurora = ramps.filter(function (s) { return s.modelData.key === "aurora"; })[0];
        win.check("a three-stop swatch previews its middle color",
                  aurora ? String(aurora.gradient.stops[1].color) : "",
                  "#15756b");

        // A mesh swatch paints through MeshGradient instead, so it must carry
        // one, with the preset's points, and no ramp of its own.
        var meshes = sw.filter(function (s) { return s.mesh; });
        win.check("the multipoint presets preview as meshes",
                  meshes.length, Model.GRADIENTS.filter(Model.gradientIsMesh).length);
        var badMesh = meshes.filter(function (s) {
            var layer = win.meshLayer(s);
            return !layer || layer.points.length !== Model.meshPoints(s.modelData).length
                || String(layer.base) !== String(s.modelData.base)
                // A mesh swatch must not also carry a ramp; QML reads a
                // gradient set to null back as undefined, not null.
                || !!s.gradient;
        });
        win.check("every mesh swatch carries its own points", badMesh.length, 0);

        // ---- crop handles --------------------------------------------------
        doc.shotWidth = 400;
        doc.shotHeight = 200;
        doc.tool = "crop";
        doc.cropRect = Qt.rect(100, 50, 200, 100);

        win.check("the top left corner is grabbed", cropper.at(100, 50), 1);
        win.check("the top right corner is grabbed", cropper.at(300, 50), 2);
        win.check("the bottom right corner is grabbed", cropper.at(300, 150), 3);
        win.check("the bottom left corner is grabbed", cropper.at(100, 150), 4);
        win.check("the inside moves the selection", cropper.at(200, 100), 5);
        win.check("and the bare picture is left to the tool", cropper.at(20, 20), 0);

        // A corner drag leaves the opposite corner where it was.
        cropper.begin(100, 50);
        cropper.dragTo(60, 20);
        win.check("a corner drag holds the far corner", win.rectText(doc.cropRect), "60,20 240x130");

        // Pulled past that corner, the selection turns inside out and stays
        // square, rather than going negative.
        cropper.dragTo(350, 180);
        win.check("and squares up when pulled past it", win.rectText(doc.cropRect), "300,150 50x30");
        // Brought right in on the far corner it is a stray drag, and lifting
        // the button there leaves no selection at all.
        cropper.dragTo(305, 155);
        win.check("a corner brought onto the other one", win.rectText(doc.cropRect), "300,150 5x5");
        cropper.finish();
        win.check("too small to keep, so it is dropped", win.rectText(doc.cropRect), "0,0 0x0");

        // Moving from the inside, and never off the picture.
        doc.cropRect = Qt.rect(100, 50, 200, 100);
        cropper.begin(200, 100);
        cropper.dragTo(210, 110);
        win.check("the inside drag moves it", win.rectText(doc.cropRect), "110,60 200x100");
        cropper.dragTo(4000, 4000);
        win.check("and stops at the edge of the picture", win.rectText(doc.cropRect), "200,100 200x100");
        cropper.finish();
        win.check("a move that size is still a crop", doc.cropUsable, true);

        // ---- the drawing surface hovers as well as drags ------------------
        // The crop selection used to follow the pointer with no button down,
        // and picking the tool was enough to start one.
        doc.cropRect = Qt.rect(0, 0, 0, 0);
        editor.drawMove(300, 150, false);
        win.check("a move with no button down draws nothing",
                  win.rectText(doc.cropRect), "0,0 0x0");
        editor.drawMove(300, 150, true);
        win.check("and with one down it draws", win.rectText(doc.cropRect), "0,0 300x150");

        doc.tool = "box";
        doc.clearAnnotations();
        var box = Model.newAnnotation("box", 10, 10);
        doc.addAnnotation(box);
        editor.drawMove(100, 80, false);
        win.check("an annotation is not resized by a hover",
                  doc.annotations.get(0).w, 0);

        // ---- what a crop cuts away -----------------------------------------
        doc.clearAnnotations();
        var keep = Model.newAnnotation("box", 20, 20); keep.w = 40; keep.h = 40;
        var half = Model.newAnnotation("box", 180, 20); half.w = 60; half.h = 40;
        var gone = Model.newAnnotation("box", 400, 300); gone.w = 40; gone.h = 40;
        var mark = Model.newAnnotation("step", 500, 500); mark.w = 30; mark.h = 30;
        doc.annotations.append(keep);
        doc.annotations.append(half);
        doc.annotations.append(gone);
        doc.annotations.append(mark);
        doc.selectedId = mark.uid;
        doc.annotationsEdited();

        win.check("two marks are cut away with the picture", doc.dropOutside(200, 200), 2);
        win.check("and the rest stay", doc.annotations.count, 2);
        win.check("including one only half inside", doc.annotations.get(1).x, 180);
        win.check("nothing is left selected that is gone", doc.selectedId, "");

        // Restyling reaches what is in hand, and leaves the rest alone.
        doc.selectedId = doc.annotations.get(0).uid;
        win.check("the selected mark is restyled", doc.styleSelection("color", "#00ff00"), true);
        win.check("in the model", String(doc.annotations.get(0).color), "#00ff00");
        win.check("and its neighbour is untouched", String(doc.annotations.get(1).color), "");
        doc.selectedId = "";
        win.check("with nothing selected there is nothing to restyle",
                  doc.styleSelection("color", "#ff0000"), false);

        // ---- handles on the selected mark ----------------------------------
        doc.clearAnnotations();
        doc.tool = "select";
        var one = Model.newAnnotation("box", 40, 20);
        one.w = 120; one.h = 60;
        doc.annotations.append(one);
        var two = Model.newAnnotation("arrow", 200, 100);
        two.w = 80; two.h = -40;
        doc.annotations.append(two);
        doc.annotationsEdited();

        win.check("nothing selected, no handles", win.knobs(marks, []).length, 0);

        doc.selectedId = one.uid;
        var k = win.knobs(marks, []);
        win.check("a box is held at four corners", k.length, 4);
        var keys = k.map(function (h) { return h.spot.key; }).sort().join(" ");
        win.check("one at each", keys, "bl br tl tr");

        // A handle is placed against the mark's own origin, so it travels with
        // the item while a move is dragged; measured from the model it would
        // sit still and jump into place on release.
        var tl = win.knobs(marks, []).filter(function (h) { return h.spot.key === "tl"; })[0];
        var held = win.entries(marks, [])[0];
        win.check("a handle sits on its corner",
                  Math.round(held.x + tl.x + tl.width / 2), 40);
        held.x += 30;
        win.check("and moves with the mark as it is dragged",
                  Math.round(held.x + tl.x + tl.width / 2), 70);
        held.x -= 30;

        doc.selectedId = two.uid;
        var ends = win.knobs(marks, []);
        win.check("an arrow is held at its two ends", ends.length, 2);
        win.check("one of them being the tip",
                  ends.filter(function (h) { return h.spot.key === "tip"; }).length, 1);

        // The auto swatches are keyed by their place in the palette, which is
        // the other delegate index in the editor.
        doc.kind = "shot";
        doc.bgMode = "auto";
        doc.autoPalette = ["#111111", "#222222", "#333333"];
        var pal = [];
        (function walk(item) {
            for (var i = 0; i < item.children.length; i++) {
                var c = item.children[i];
                if (c.hasOwnProperty("swatchColor") && c.hasOwnProperty("index")) pal.push(c);
                walk(c);
            }
        })(inspector);
        win.check("the auto swatches know their place",
                  pal.map(function (c) { return c.index; }).join(","), "0,1,2");

        // ---- one mark moves, the others stay -------------------------------
        doc.clearAnnotations();
        var m1 = Model.newAnnotation("box", 10, 10); m1.w = 50; m1.h = 50;
        var m2 = Model.newAnnotation("box", 100, 100); m2.w = 50; m2.h = 50;
        var m3 = Model.newAnnotation("arrow", 200, 40); m3.w = 60; m3.h = 30;
        doc.annotations.append(m1);
        doc.annotations.append(m2);
        doc.annotations.append(m3);
        doc.annotationsEdited();

        var es = win.entries(marks, []);
        win.check("one delegate per mark", es.length, 3);
        // A drag moves the delegate itself; the release writes it back.
        es[1].x = es[1].x + 30;
        es[1].y = es[1].y + 20;
        es[1].commit();
        es[1].rebind();
        win.check("the one dragged moved",
                  doc.annotations.get(1).x + "," + doc.annotations.get(1).y, "130,120");
        win.check("the first stayed where it was",
                  doc.annotations.get(0).x + "," + doc.annotations.get(0).y, "10,10");
        win.check("and so did the third",
                  doc.annotations.get(2).x + "," + doc.annotations.get(2).y, "200,40");

        // What a press on a mark does depends on the tool: with the move tool
        // every mark is there to be taken, with a tool that draws only the
        // one just drawn, and while cropping none of them are.
        function grabs() {
            return win.entries(marks, []).map(function (e) { return e.grabbable ? "1" : "0"; }).join("");
        }
        doc.selectedId = doc.annotations.get(1).uid;
        doc.tool = "select";
        win.check("with the move tool, any of them", grabs(), "111");
        doc.tool = "box";
        win.check("with a drawing tool, the one in hand", grabs(), "010");
        doc.selectedId = "";
        win.check("and none when nothing is selected", grabs(), "000");
        doc.selectedId = doc.annotations.get(1).uid;
        doc.tool = "crop";
        win.check("none while cropping", grabs(), "000");
        doc.tool = "select";

        // A resize goes through the document the same way, and a patch of a
        // few properties must leave the rest of the mark alone.
        doc.annotations.setProperty(1, "color", "#123456");
        doc.updateAnnotation(doc.annotations.get(1).uid, { x: 60, y: 70, w: 80, h: 90 });
        var r = doc.annotations.get(1);
        win.check("resized", r.x + "," + r.y + " " + r.w + "x" + r.h, "60,70 80x90");
        win.check("still the same kind of mark", r.kind, "box");
        win.check("and the same color", String(r.color), "#123456");

        Qt.quit();
    })
}
