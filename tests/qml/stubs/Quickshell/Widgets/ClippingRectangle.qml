import QtQuick

// Test stand-in: Quickshell's ClippingRectangle needs the Quickshell host, so
// the offscreen render uses a plain clipped Rectangle. Rounded clipping is
// verified in the live shell instead.
Rectangle {
    clip: true
}
