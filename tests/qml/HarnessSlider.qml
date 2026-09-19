import QtQuick
import "../../ui/controls"

// LabeledSlider's readout is an editable field, which means its text binding
// is broken the moment anyone types into it. This drives that field directly
// and checks the value round trip; tests/qml/render.sh greps the output.
Item {
    id: win
    width: 300
    height: 200

    property real model: 5

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

        Qt.quit();
    })
}
