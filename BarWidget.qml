import QtQuick
import qs.Commons
import qs.Ui
import "ui"

BarWidget {
    id: root
    moduleName: "tahayvr.omasnap"

    readonly property string icon: root.setting("icon", "󰆟")

    readonly property color fg: root.bar ? root.bar.foreground : Color.popups.text
    readonly property string face: root.bar && root.bar.fontFamily
                                   ? root.bar.fontFamily : Style.font.family

    // Right-click opens this. Left and middle click stay direct: the two
    // things worth reaching for without reading anything.
    readonly property var actions: [
        { glyph: "⬚",       label: "Region", payload: '{"capture":"region"}',
          tip: "Capture a region" },
        { glyph: "◰",       label: "Window", payload: '{"capture":"windows"}',
          tip: "Capture a window" },
        { glyph: "‹›", label: "Code",   payload: '{"code":true}',
          tip: "Capture selected text" }
    ]

    implicitWidth: button.implicitWidth
    implicitHeight: barSize

    function summon(payload) {
        root.bar.shell.summon(root.moduleName, payload);
    }

    function choose(payload) {
        menu.open = false;
        root.summon(payload);
    }

    WidgetButton {
        id: button
        anchors.centerIn: parent
        bar: root.bar
        text: root.icon
        tooltipText: "OmaSnap"
        useActiveColor: false
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.RightButton) menu.open = !menu.open;
            else if (mouseButton === Qt.MiddleButton) root.summon('{"code":true}');
            else root.summon('{"capture":"smart"}');
        }
    }

    PopupCard {
        id: menu
        anchorItem: button
        bar: root.bar
        contentWidth: menu.fittedContentWidth(Style.space(240))
        contentHeight: menu.fittedContentHeight(body.implicitHeight)

        Column {
            id: body
            width: parent.width
            spacing: Style.space(10)

            // The wordmark is the way in rather than a heading: clicking it
            // opens the editor, which is why there is no row for that.
            Rectangle {
                width: parent.width
                height: Style.spacing.popupRowHeight
                radius: Style.cornerRadius
                color: markHover.hovered
                       ? Style.hoverFillFor(root.fg, Color.accent) : "transparent"

                Wordmark {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    markHeight: Style.space(15)
                    tint: root.fg
                }

                HoverHandler {
                    id: markHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: root.choose('{}')
                }
                PanelToolTip {
                    visible: markHover.hovered
                    text: "Open the editor"
                }
            }

            PanelSeparator { foreground: root.fg }

            Column {
                width: parent.width

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: row
                        required property var modelData
                        width: parent.width
                        height: Style.spacing.popupRowHeight
                        radius: Style.cornerRadius
                        color: hover.hovered
                               ? Style.hoverFillFor(root.fg, Color.accent) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            spacing: Style.space(12)

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Style.font.icon
                                horizontalAlignment: Text.AlignHCenter
                                text: row.modelData.glyph
                                color: Qt.darker(root.fg, 1.3)
                                font.family: root.face
                                font.pixelSize: Style.font.icon
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                color: root.fg
                                font.family: root.face
                                font.pixelSize: Style.font.body
                            }
                        }

                        HoverHandler {
                            id: hover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: root.choose(row.modelData.payload)
                        }

                        PanelToolTip {
                            visible: hover.hovered
                            text: row.modelData.tip
                        }
                    }
                }
            }
        }
    }
}
