import QtQuick
import QtQuick.Window
import "../../ui"
import "../../ui/controls"

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

        Qt.quit();
    })
}
