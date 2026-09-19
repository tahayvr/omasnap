#!/usr/bin/python3
"""Open the system file picker through the XDG desktop portal and print the
chosen path. Usage: snap-portal.py [start-directory]. Prints nothing when
cancelled. Set OMASNAP_PICK_TIMEOUT (seconds) to auto-cancel.

A one-shot D-Bus CLI cannot do this: the portal closes a request as soon as
the calling connection disconnects, so the connection has to stay open until
the Response signal arrives."""
import os
import sys
import urllib.parse

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

start = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else os.path.expanduser("~/Pictures")
if not os.path.isdir(start):
    start = os.path.expanduser("~")

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
sender = bus.get_unique_name()[1:].replace(".", "_")
token = "omasnap%d" % os.getpid()
request = "/org/freedesktop/portal/desktop/request/%s/%s" % (sender, token)

loop = GLib.MainLoop()
chosen = []


def on_response(_conn, _sender, _path, _iface, _signal, params):
    code, results = params.unpack()
    if code == 0:
        chosen.extend(results.get("uris", []))
    loop.quit()


def subscribe(path):
    bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request",
                         "Response", path, None, Gio.DBusSignalFlags.NONE, on_response)


subscribe(request)

options = {
    "handle_token": GLib.Variant("s", token),
    "accept_label": GLib.Variant("s", "Open"),
    "modal": GLib.Variant("b", True),
    "multiple": GLib.Variant("b", False),
    "filters": GLib.Variant("a(sa(us))", [
        ("Images", [(0, "*.png"), (0, "*.jpg"), (0, "*.jpeg"), (0, "*.webp"), (0, "*.PNG"), (0, "*.JPG")]),
        ("All files", [(0, "*")]),
    ]),
    "current_folder": GLib.Variant("ay", start.encode() + b"\0"),
}
reply = bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                      "org.freedesktop.portal.FileChooser", "OpenFile",
                      GLib.Variant("(ssa{sv})", ("", "Open an image", options)),
                      GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE, -1, None)
handle = reply.unpack()[0]
if handle != request:
    subscribe(handle)


def give_up():
    try:
        bus.call_sync("org.freedesktop.portal.Desktop", handle, "org.freedesktop.portal.Request",
                      "Close", None, None, Gio.DBusCallFlags.NONE, -1, None)
    except GLib.Error:
        pass
    loop.quit()
    return False


timeout = float(os.environ.get("OMASNAP_PICK_TIMEOUT", "0") or 0)
if timeout > 0:
    GLib.timeout_add(int(timeout * 1000), give_up)

loop.run()
for uri in chosen:
    if uri.startswith("file://"):
        print(urllib.parse.unquote(uri[7:]))
        break
