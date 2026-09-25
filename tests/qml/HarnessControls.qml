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
        doc.shotPath = "/tmp/postcard-example.png";
        var first = String(doc.shotUrl);
        win.check("shot url carries a revision", first.indexOf("#v") > 0, true);
        doc.shotRevision += 1;
        win.check("reloading the same path changes the url",
                  String(doc.shotUrl) !== first, true);
        win.check("and still points at the file",
                  String(doc.shotUrl).indexOf("/tmp/postcard-example.png") > 0, true);

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

        // ---- presets -------------------------------------------------------
        doc.presets = [];
        doc.reset();
        win.check("the card starts on Default, unchanged", doc.activePreset + " " + doc.presetModified, "default false");
        doc.inkColor = "#00ff00";
        doc.tool = "arrow";
        win.check("the ink and the tool are not part of the look", doc.presetModified, false);
        doc.padding = 12;
        doc.bgMode = "solid";
        doc.bgSolid = "#123456";
        win.check("a change to the look shows against the preset", doc.presetModified, true);

        inspector.startNaming();
        win.check("+ opens the name field", inspector.naming, true);
        var made = doc.savePresetAs("  Social   post ");
        win.check("saving names it tidily", doc.activePresetEntry.name, "Social post");
        win.check("and puts it in use, unchanged", doc.activePreset === made && !doc.presetModified, true);

        doc.radius = 9;
        win.check("a later change shows again", doc.presetModified, true);
        doc.updatePreset();
        win.check("Update writes it to the preset", doc.presets[0].style.radius + " " + doc.presetModified, "9 false");

        doc.savePresetAs("social POST");
        win.check("the same name updates rather than duplicating", doc.presets.length, 1);

        doc.applyPreset("default");
        win.check("Default puts the defaults back", doc.padding + " " + doc.bgMode, "5 auto");
        win.check("and leaves the ink alone", String(doc.inkColor), "#00ff00");
        doc.applyPreset(made);
        win.check("a saved preset comes back whole",
                  doc.padding + " " + doc.bgMode + " " + String(doc.bgSolid) + " " + doc.radius, "12 solid #123456 9");

        inspector.deletePreset();
        win.check("delete wants a second click", doc.presets.length, 1);
        inspector.deletePreset();
        win.check("and then deletes", doc.presets.length + " " + doc.activePreset, "0 default");
        win.check("leaving the card as it was", doc.padding, 12);
        doc.reset();
        win.check("reset is Default again", doc.padding + " " + doc.presetModified, "5 false");
        doc.tool = "select";

        // ---- custom colors -------------------------------------------------
        doc.customColors = [];
        doc.bgMode = "solid";
        inspector.openPicker("solid");
        win.check("the picker opens on the solid color", inspector.pickerTarget, "solid");
        inspector.commitPicked("solid", "#123456");
        win.check("a pick becomes the background", String(doc.bgSolid), "#123456");
        win.check("and a recent color", doc.customColors.join(" "), "#123456");
        inspector.commitPicked("solid", "#654321");
        win.check("a second pick in one visit replaces it", doc.customColors.join(" "), "#654321");
        inspector.openPicker("solid");
        inspector.openPicker("solid");
        inspector.commitPicked("solid", "#abcdef");
        win.check("a fresh visit adds one", doc.customColors.join(" "), "#abcdef #654321");
        inspector.forgetColor("#abcdef");
        win.check("a color of your own can be removed", doc.customColors.join(" "), "#654321");
        win.check("and a background in that color stays as it is", String(doc.bgSolid), "#abcdef");

        doc.bgMode = "gradient";
        win.check("changing mode closes the picker", inspector.pickerTarget, "");
        doc.customColors = [];
        doc.userGradients = [];
        doc.bgGradient = "ember";
        inspector.newGradient();
        win.check("a new gradient is saved", doc.userGradients.length, 1);
        win.check("starting from the one on show", doc.bgCustomStops.join(" "), "#7a2e2e #e0764a");
        win.check("and is put on the card", doc.bgGradient + " " + (doc.bgCustomId === doc.userGradients[0].id), "custom true");
        inspector.addStop();
        win.check("adding a stop opens the picker on it", inspector.pickerTarget, "stop2");
        inspector.commitPicked("stop2", "#333333");
        win.check("and edits that stop alone", doc.bgCustomStops.join(" "), "#7a2e2e #e0764a #333333");
        win.check("the saved gradient follows", doc.userGradients[0].stops.join(" "), "#7a2e2e #e0764a #333333");
        win.check("its colors are not kept one by one", doc.customColors.length, 0);
        inspector.setAngle(33);
        win.check("nor is its angle lost", doc.userGradients[0].angle, 33);
        inspector.openPicker("stop0");
        inspector.removeStop();
        win.check("removing takes the stop being edited", doc.userGradients[0].stops.join(" "), "#e0764a #333333");
        inspector.removeStop();
        win.check("but never below two", doc.bgCustomStops.length, 2);

        var kept = doc.userGradients[0].id;
        doc.bgGradient = "dusk";
        inspector.newGradient();
        win.check("a second one goes in front", doc.userGradients.length + " " + (doc.userGradients[1].id === kept), "2 true");
        inspector.showGradient(doc.userGradients[1]);
        win.check("a saved one is put back on the card", doc.bgCustomStops.join(" ") + " " + doc.bgCustomAngle,
                  "#e0764a #333333 33");
        inspector.forgetGradient(kept);
        win.check("deleting it leaves one saved", doc.userGradients.length, 1);
        win.check("but the card keeps it", doc.bgGradient + " " + doc.bgCustomStops.join(" "), "custom #e0764a #333333");
        inspector.commitPicked("stop0", "#010101");
        win.check("and editing it no longer touches what is saved",
                  doc.userGradients[0].stops.indexOf("#010101"), -1);
        doc.customColors = [];
        doc.userGradients = [];
        doc.bgCustomId = "";
        doc.bgMode = "auto";
        doc.bgGradient = "dusk";

        // ---- magnifier -----------------------------------------------------
        doc.clearAnnotations();
        doc.shotWidth = 800;
        doc.shotHeight = 400;
        var mag = Model.newAnnotation("magnify", 0, 0);
        var drawn = Model.magnifyFromDrag(380, 180, 420, 220, 2);
        for (var mk in drawn) mag[mk] = drawn[mk];
        mag.zoom = 2;
        doc.addAnnotation(mag);
        editor.finishMagnifier(mag.uid);
        var placed = doc.selectedAnnotation();
        var link = Model.magnifyLink(placed.x + placed.w / 2, placed.y + placed.h / 2, placed.w / 2,
                                     placed.sx, placed.sy, placed.w / 2 / placed.zoom);
        win.check("letting go sets the lens beside what it shows", link !== null, true);
        win.check("still showing the middle of the drag", placed.sx + "," + placed.sy, "400,200");

        doc.setMagnifyZoom(4);
        placed = doc.selectedAnnotation();
        win.check("the zoom buttons change the one in hand", placed.zoom + " " + placed.w, "4 80");
        win.check("and the next one", doc.magnifyZoom, 4);
        doc.setMagnifyZoom(2);

        doc.shiftAnnotations(-100, -50);
        placed = doc.selectedAnnotation();
        win.check("a crop moves what it shows along with the picture", placed.sx + "," + placed.sy, "300,150");

        var stray = Model.newAnnotation("magnify", 0, 0);
        var small = Model.magnifyFromDrag(100, 100, 104, 103, 2);
        for (var sk in small) stray[sk] = small[sk];
        doc.addAnnotation(stray);
        editor.finishMagnifier(stray.uid);
        win.check("a stray drag leaves no magnifier", doc.indexOfId(stray.uid), -1);
        doc.clearAnnotations();

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
        win.check("the top side is grabbed", cropper.at(200, 50), 6);
        win.check("the right side is grabbed", cropper.at(300, 100), 7);
        win.check("the bottom side is grabbed", cropper.at(200, 150), 8);
        win.check("the left side is grabbed", cropper.at(100, 100), 9);
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

        // A side moves its own edge and nothing else, whichever way the
        // pointer strays along it.
        doc.cropRect = Qt.rect(100, 50, 200, 100);
        cropper.begin(200, 50);
        cropper.dragTo(250, 30);
        win.check("the top side moves only the top", win.rectText(doc.cropRect), "100,30 200x120");
        cropper.dragTo(0, 180);
        win.check("and squares up when pulled past the bottom", win.rectText(doc.cropRect), "100,150 200x30");
        cropper.finish();

        doc.cropRect = Qt.rect(100, 50, 200, 100);
        cropper.begin(300, 100);
        cropper.dragTo(360, 0);
        win.check("the right side moves only the right", win.rectText(doc.cropRect), "100,50 260x100");
        cropper.finish();

        doc.cropRect = Qt.rect(100, 50, 200, 100);
        cropper.begin(200, 150);
        cropper.dragTo(10, 170);
        win.check("the bottom side moves only the bottom", win.rectText(doc.cropRect), "100,50 200x120");
        cropper.finish();

        doc.cropRect = Qt.rect(100, 50, 200, 100);
        cropper.begin(100, 100);
        cropper.dragTo(-50, 400);
        win.check("the left side stops at the edge of the picture", win.rectText(doc.cropRect), "0,50 300x100");
        cropper.finish();

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

        // ---- several marks at once -----------------------------------------
        doc.clearAnnotations();
        var trio = [];
        for (var t = 0; t < 3; t++) {
            var m3 = Model.newAnnotation("box", t * 100, 10);
            m3.w = 40; m3.h = 40;
            doc.annotations.append(m3);
            trio.push(m3.uid);
        }
        doc.annotationsEdited();
        doc.selectedId = trio[0];
        doc.toggleSelected(trio[2]);
        win.check("shift adds a mark to the selection", doc.selectedIds.length, 2);
        win.check("and puts it in hand", doc.selectedId, trio[2]);
        doc.toggleSelected(trio[2]);
        win.check("and again takes it out", doc.selectedIds.join(), trio[0]);
        doc.selectedId = trio[1];
        win.check("a plain pick selects that mark alone", doc.selectedIds.join(), trio[1]);
        doc.selectInBox(0, 0, 150, 60, false);
        win.check("a box takes what it touches", doc.selectedIds.length, 2);
        doc.selectInBox(190, 0, 20, 20, true);
        win.check("and with shift adds to it", doc.selectedIds.length, 3);
        doc.moveSelection(5, 7, "");
        win.check("a group moves together", doc.annotations.get(2).x + "," + doc.annotations.get(2).y, "205,17");
        doc.styleSelection("color", "#123456");
        win.check("and is restyled together", String(doc.annotations.get(0).color), "#123456");
        doc.selectMany([trio[0], trio[2]], trio[0]);
        win.check("and goes together", doc.removeSelection(), 2);
        win.check("leaving the rest", doc.annotations.get(0).uid, trio[1]);
        win.check("and nothing selected", doc.selectedIds.length + doc.selectedId.length, 0);
        doc.selectAll();
        win.check("select all", doc.selectedIds.join(), trio[1]);

        // ---- copy and paste --------------------------------------------------
        doc.clearAnnotations();
        var src = Model.newAnnotation("box", 10, 10); src.w = 40; src.h = 40;
        var num = Model.newAnnotation("step", 100, 10); num.w = 30; num.h = 30;
        doc.stepCounter = 1; num.index = 1;
        doc.annotations.append(src);
        doc.annotations.append(num);
        doc.annotationsEdited();
        doc.selectAll();
        win.check("a selection is copied", doc.copySelection(), 2);
        win.check("and pasted", doc.paste(), 2);
        win.check("beside the original", doc.annotations.get(2).x, 10 + Model.pasteStep(doc.shotWidth, doc.shotHeight));
        win.check("a pasted step carries on the count", doc.annotations.get(3).index, 2);
        win.check("the pasted marks are what is selected", doc.selectedIds.length, 2);
        doc.paste();
        win.check("a second paste steps further", doc.annotations.get(4).x,
                  10 + 2 * Model.pasteStep(doc.shotWidth, doc.shotHeight));
        doc.selectedId = doc.annotations.get(0).uid;
        win.check("duplicate copies what is selected", doc.duplicateSelection(), 1);
        win.check("without touching the clipboard", doc.markClipboard.length, 2);
        doc.clearContent();
        win.check("a new picture clears it", doc.markClipboard.length, 0);

        // ---- a step sequence closes up -------------------------------------
        doc.clearAnnotations();
        var steps = [];
        for (var n = 0; n < 5; n++) {
            var st = Model.newAnnotation("step", n * 40, 10);
            st.w = 30; st.h = 30;
            doc.stepCounter += 1;
            st.index = doc.stepCounter;
            doc.annotations.append(st);
            steps.push(st);
        }
        // A mark of another kind in among them must not take a number.
        var line = Model.newAnnotation("box", 0, 200); line.w = 40; line.h = 40;
        doc.annotations.append(line);
        doc.annotationsEdited();

        function sequence() {
            var out = [];
            for (var i = 0; i < doc.annotations.count; i++) {
                var a = doc.annotations.get(i);
                if (a.kind === "step") out.push(a.index);
            }
            return out.join(",");
        }
        win.check("five steps in order", sequence(), "1,2,3,4,5");

        // checkpoint() stands in for the settle timer after each action.
        doc.resetHistory();
        doc.removeAnnotation(steps[2].uid);
        doc.checkpoint();
        win.check("the third goes and the rest close up", sequence(), "1,2,3,4");
        win.check("so the next one carries on from the end", doc.stepCounter, 4);
        win.check("and the box is still there", doc.annotations.count, 5);

        doc.removeAnnotation(steps[0].uid);
        win.check("and again from the front", sequence(), "1,2,3");

        doc.undo();
        win.check("undo brings back what was removed last, settled or not", sequence(), "1,2,3,4");
        doc.undo();
        win.check("and the one before", sequence(), "1,2,3,4,5");
        win.check("with the counter following", doc.stepCounter, 5);
        win.check("and no further than the picture as it was", doc.undo(), false);
        doc.redo();
        win.check("redo takes it away again", sequence(), "1,2,3,4");

        // ---- the undo history ------------------------------------------------
        doc.clearAnnotations();
        doc.resetHistory();
        var hb = Model.newAnnotation("box", 10, 10); hb.w = 40; hb.h = 40;
        doc.addAnnotation(hb);
        doc.checkpoint();
        doc.moveSelection(30, 0, "");
        doc.checkpoint();
        doc.styleSelection("color", "#abcdef");
        doc.checkpoint();
        doc.undo();
        win.check("undo takes back a restyle", String(doc.annotations.get(0).color), String(hb.color));
        doc.undo();
        win.check("and a move", doc.annotations.get(0).x, 10);
        doc.redo();
        win.check("redo moves it again", doc.annotations.get(0).x, 40);
        win.check("with more to redo", doc.canRedo, true);
        doc.selectedId = doc.annotations.get(0).uid;
        doc.moveSelection(0, 5, "");
        win.check("a new edit is undoable at once", doc.canUndo, true);
        doc.checkpoint();
        win.check("and leaves nothing to redo", doc.canRedo, false);
        doc.selectAll();
        doc.removeSelection();
        doc.checkpoint();
        doc.undo();
        win.check("a delete is undone", doc.annotations.count, 1);
        win.check("to where it was", doc.annotations.get(0).y, 15);
        doc.pressing = true;
        win.check("nothing is undone while a press is under way", doc.undo(), false);
        doc.pressing = false;
        var stepsBefore = doc.history.length;
        var hbLabel = Model.newAnnotation("text", 5, 5);
        doc.addAnnotation(hbLabel);
        doc.checkpoint();
        win.check("a label with nothing typed is not a step", doc.history.length, stepsBefore);
        doc.updateAnnotation(hbLabel.uid, { text: "hi" });
        doc.checkpoint();
        win.check("once it says something it is", doc.history.length, doc.historyAt + 1);
        win.check("and redo is gone", doc.canRedo, false);
        doc.clearContent();
        win.check("a new picture starts the history again", doc.canUndo, false);

        // What a crop cuts away leaves the same tidy sequence behind.
        doc.clearAnnotations();
        for (var j = 0; j < 4; j++) {
            var sp = Model.newAnnotation("step", j * 300, 10);
            sp.w = 30; sp.h = 30;
            doc.stepCounter += 1;
            sp.index = doc.stepCounter;
            doc.annotations.append(sp);
        }
        doc.annotationsEdited();
        win.check("four steps across the picture", sequence(), "1,2,3,4");
        doc.dropOutside(320, 200);
        win.check("two are cut away and the rest close up", sequence(), "1,2");

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
        win.check("a box is held at its corners and sides", k.length, 8);
        var keys = k.map(function (h) { return h.spot.key; }).sort().join(" ");
        win.check("one at each", keys, "b bl br l r t tl tr");

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

        var top = win.knobs(marks, []).filter(function (h) { return h.spot.key === "t"; })[0];
        win.check("a side bar sits at the middle of its edge",
                  Math.round(held.x + top.x + top.width / 2) + "," + Math.round(held.y + top.y + top.height / 2),
                  "100,20");
        win.check("and lies along it", top.width > top.height, true);

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
                if (c.hasOwnProperty("swatchColor") && c.hasOwnProperty("index") && c.visible) pal.push(c);
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
