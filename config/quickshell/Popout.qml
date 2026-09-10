import QtQuick
import Quickshell

// Shared shell for every bar popup: a fullscreen transparent catcher
// window with the styled card anchored under its bar item. Clicking
// anywhere outside the card closes it; Escape too (when X grants the
// popup key focus). All popups use this, so chrome and behavior stay
// identical.
// On Wayland (Sys.composited is false here) the window is card-only:
// an xdg-popup the size of the card under its bar item, no catcher.
// Click-outside close is lost in that mode; Escape and the module's own
// toggle still close.
// Note: spans the primary screen — revisit offsets if a second monitor
// ever joins.
PopupWindow {
    id: root

    property Item anchorItem
    property real cardWidth: 300
    property real cardHeight: 300
    readonly property real cardPadding: 14
    // right-edge panel mode (control center) instead of centered-under-anchor
    property bool alignRight: false

    readonly property bool catcher: Sys.composited

    default property alias content: inner.data

    visible: false
    color: "transparent"

    anchor.item: anchorItem
    // catcher mode: stretch the window over the whole screen so outside
    // clicks land on it; card-only mode: the window IS the card
    anchor.rect.x: catcher ? (anchorItem ? -anchorItem.mapToGlobal(0, 0).x : 0)
                           : uOffsetX
    anchor.rect.y: catcher ? (anchorItem ? -anchorItem.mapToGlobal(0, 0).y : 0)
                           : (anchorItem?.height ?? 0) + 12
    implicitWidth: catcher
        ? (Quickshell.screens.length ? Quickshell.screens[0].width : 1920)
        : cardWidth
    implicitHeight: catcher
        ? (Quickshell.screens.length ? Quickshell.screens[0].height : 1080)
        : cardHeight

    // anchor's global position, captured at open time — mapToGlobal in a
    // static binding evaluates before the item is mapped and returns 0
    property real ax: 0
    property real ay: 0
    // card-only mode: window x offset from the anchor item, clamped to
    // the screen like the catcher-mode card
    property real uOffsetX: 0

    onVisibleChanged: {
        if (visible && anchorItem) {
            const p = anchorItem.mapToGlobal(0, 0)
            ax = p.x
            ay = p.y
            const sw = Quickshell.screens.length ? Quickshell.screens[0].width : 1920
            const desired = alignRight ? sw - cardWidth - 8
                : Math.min(Math.max(ax + anchorItem.width / 2 - cardWidth / 2, 8),
                           sw - cardWidth - 8)
            uOffsetX = desired - ax
            inner.forceActiveFocus()
            enterAnim.restart()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        id: card

        x: !root.catcher ? 0
         : root.alignRight ? root.width - width - 8
         : Math.min(Math.max(root.ax + (root.anchorItem?.width ?? 0) / 2 - width / 2, 8),
                    root.width - width - 8)
        y: root.catcher ? root.ay + (root.anchorItem?.height ?? 0) + 12 : 0

        transform: Translate { id: slide; y: 0 }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: slide; property: "y"; from: -10; to: 0
                              duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1
                              duration: 160 }
        }
        width: root.cardWidth
        height: root.cardHeight
        radius: 12
        color: Theme.bg
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.4)

        Behavior on color { ColorAnimation { duration: 250 } }

        // swallow card clicks so they don't fall through to the catcher
        MouseArea { anchors.fill: parent }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: root.cardPadding
            focus: true
            Keys.onEscapePressed: root.visible = false
        }
    }
}
