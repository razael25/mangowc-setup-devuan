import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// App launcher (Super+space, or left-click the Debian swirl): a grid of
// every installed app, centered on screen. Type to search (name, generic
// name, keywords, program); arrows move, Enter launches, Esc clears and
// then closes. Chips narrow it to Apps or Settings (the .desktop
// "Settings" category: display, sound, GTK, power and the like — not the
// broader "System", which also claims terminals and file managers);
// Ctrl+Tab cycles them.
// With nothing typed the grid is alphabetical, so every app keeps its
// spot. How often and how recently you launch something (launcher-history
// in the config folder) only breaks ties between search matches.
// Icons follow the GTK icon theme: scripts/bar hands it to quickshell
// through QS_ICON_THEME at start.
Popout {
    id: root

    property string query: ""
    property int chip: 0                 // index into chips
    property int selected: 0
    property var history: ({})           // id → {count, last (epoch s)}

    readonly property var chips: ["All", "Apps", "Settings"]
    readonly property int columns: 6
    readonly property int cellW: 112
    readonly property int cellH: 100
    readonly property real screenH: screen ? screen.height : 1080
    readonly property string historyFile: Theme.configDir + "/launcher-history"

    // quickshell fills this in the background after start; the binding
    // follows along, so an early open just shows what's scanned so far
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    readonly property var results: search(apps, query, chip, history)

    centered: true
    cardWidth: columns * cellW + 2 * cardPadding
    // sized for every app, not the current matches, so typing doesn't
    // make the card jump
    cardHeight: Math.min(header.height + 12 + Math.ceil(Math.max(apps.length, 1) / columns) * cellH
                         + 12 + footer.height + 2 * cardPadding,
                         screenH * 0.85)

    // scriptable: qs -p ~/.config/mango/quickshell ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.visible = !root.visible }
    }

    onVisibleChanged: {
        if (!visible)
            return
        field.text = ""
        chip = 0
        selected = 0
        grid.positionViewAtBeginning()
        // after Popout's own focus grab on open
        Qt.callLater(() => field.forceActiveFocus())
    }
    onResultsChanged: selected = 0

    FileView {
        path: root.historyFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const h = {}
            for (const l of text().split("\n")) {
                const f = l.split("\t")
                if (f.length === 3)
                    h[f[2]] = { count: Number(f[0]), last: Number(f[1]) }
            }
            root.history = h
        }
    }

    function isSettings(a) {
        return a.categories.includes("Settings")
    }

    // how well one lowercase word matches an app: 0 = not at all
    function wordScore(a, w) {
        const name = a.name.toLowerCase()
        if (name.startsWith(w)) return 100
        if (name.split(/[\s\-_.]+/).some(p => p.startsWith(w))) return 80
        if (name.includes(w)) return 60
        const prog = (a.command[0] ?? "").split("/").pop().toLowerCase()
        if (prog.startsWith(w)) return 50
        const extra = [a.genericName, ...a.keywords].join(" ").toLowerCase()
        if (extra.split(/[\s;,\-]+/).some(p => p.startsWith(w))) return 40
        if (extra.includes(w) || prog.includes(w)) return 25
        return 0
    }

    // launches, fading with time since the last one (half weight a week on)
    function frecency(id, hist) {
        const h = hist[id]
        if (!h) return 0
        const days = (Date.now() / 1000 - h.last) / 86400
        return h.count / (1 + Math.max(days, 0) / 7)
    }

    function search(list, q, chipIndex, hist) {
        let pool = list
        if (chipIndex === 1) pool = pool.filter(a => !isSettings(a))
        else if (chipIndex === 2) pool = pool.filter(a => isSettings(a))

        const words = q.toLowerCase().split(/\s+/).filter(w => w !== "")
        if (!words.length)
            return pool.slice().sort((a, b) => a.name.localeCompare(b.name))

        const scored = []
        for (const a of pool) {
            let s = 0
            for (const w of words) {
                const ws = wordScore(a, w)
                if (!ws) { s = 0; break }
                s += ws
            }
            if (s)
                scored.push({ app: a, s: s, f: frecency(a.id, hist) })
        }
        scored.sort((x, y) => y.s - x.s || y.f - x.f || x.app.name.localeCompare(y.app.name))
        return scored.map(x => x.app)
    }

    function launch(a) {
        if (!a)
            return
        remember(a.id)
        root.visible = false
        if (a.runInTerminal)
            Quickshell.execDetached(["kitty", "-e"].concat(a.command))
        else
            a.execute()
    }

    // count + last launch per app id; the whole file is rewritten, one
    // line per app, values passed as arguments (never spliced into sh)
    function remember(id) {
        const h = Object.assign({}, history)
        const prev = h[id] ?? { count: 0, last: 0 }
        h[id] = { count: prev.count + 1, last: Math.floor(Date.now() / 1000) }
        history = h
        const lines = Object.keys(h).map(k => h[k].count + "\t" + h[k].last + "\t" + k)
        Quickshell.execDetached(["sh", "-c", "f=$1; shift; printf '%s\\n' \"$@\" > \"$f\"",
                                 "sh", historyFile].concat(lines))
    }

    function move(d) {
        if (!results.length)
            return
        selected = Math.max(0, Math.min(results.length - 1, selected + d))
        grid.positionViewAtIndex(selected, GridView.Contain)
    }

    Column {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Rectangle {
            width: parent.width
            height: 36
            radius: 8
            color: Qt.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"

            Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }

            TextInput {
                id: field
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                selectionColor: Qt.alpha(Theme.accent, 0.4)
                font.family: Theme.fontFamily
                font.pixelSize: 13
                clip: true
                onTextChanged: root.query = text

                Keys.onPressed: event => {
                    const k = event.key
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (k === Qt.Key_Tab && ctrl || k === Qt.Key_Backtab && ctrl) {
                        root.chip = (root.chip + (k === Qt.Key_Backtab ? root.chips.length - 1 : 1)) % root.chips.length
                    } else if (k === Qt.Key_Right || k === Qt.Key_Tab)
                        root.move(1)
                    else if (k === Qt.Key_Left || k === Qt.Key_Backtab)
                        root.move(-1)
                    else if (k === Qt.Key_Down)
                        root.move(root.columns)
                    else if (k === Qt.Key_Up)
                        root.move(-root.columns)
                    else if (k === Qt.Key_PageDown)
                        root.move(root.columns * Math.max(1, Math.floor(grid.height / root.cellH)))
                    else if (k === Qt.Key_PageUp)
                        root.move(-root.columns * Math.max(1, Math.floor(grid.height / root.cellH)))
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                        root.launch(root.results[root.selected])
                    else if (k === Qt.Key_Escape && text !== "")
                        text = ""
                    else {
                        // typing, and a plain Escape on to Popout (closes)
                        event.accepted = false
                        return
                    }
                    event.accepted = true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: "Search apps"
                    color: Qt.alpha(Theme.fg, 0.35)
                    font: field.font
                }
            }
        }

        Row {
            spacing: 6

            Repeater {
                model: root.chips

                Rectangle {
                    id: chipItem
                    required property string modelData
                    required property int index
                    readonly property bool active: root.chip === index
                    width: chipText.implicitWidth + 20
                    height: 24
                    radius: 12
                    color: active ? Theme.accent
                         : chipMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chipItem.modelData
                        color: chipItem.active ? Theme.bg : Qt.alpha(Theme.fg, 0.8)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: chipItem.active
                    }

                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.chip = chipItem.index
                            field.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: root.cellW
        cellHeight: root.cellH
        model: root.results
        currentIndex: root.selected
        highlightFollowsCurrentItem: false

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool current: root.selected === index
            width: root.cellW
            height: root.cellH

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 10
                color: cell.current ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                border.width: cell.current ? 1 : 0
                border.color: Qt.alpha(Theme.accent, 0.5)
            }

            IconImage {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                implicitSize: 44
                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
            }

            Text {
                anchors.top: icon.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: cell.modelData.name
                color: cell.current ? Theme.accent : Qt.alpha(Theme.fg, 0.85)
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selected = cell.index
                onClicked: root.launch(cell.modelData)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.apps.length === 0 ? "loading apps…" : "No apps match \"" + root.query + "\""
            color: Qt.alpha(Theme.fg, 0.5)
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    // only when the grid is taller than the card (768p laptops)
    Rectangle {
        visible: grid.contentHeight > grid.height
        anchors.right: grid.right
        anchors.rightMargin: -8
        y: grid.y + grid.visibleArea.yPosition * grid.height
        width: 3
        height: grid.visibleArea.heightRatio * grid.height
        radius: 2
        color: Qt.alpha(Theme.fg, 0.3)
    }

    Text {
        id: footer
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: "↵ open · arrows move · ctrl+tab " + root.chips[(root.chip + 1) % root.chips.length].toLowerCase()
            + " · esc close"
        color: Qt.alpha(Theme.fg, 0.35)
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
