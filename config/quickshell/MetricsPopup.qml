import QtQuick
import Quickshell
import Quickshell.Io

// What's using the machine: CPU and RAM bars, then the busiest programs.
// Opens from the Metrics module. Per-program CPU comes from two
// scripts/procs snapshots a couple of seconds apart (ps would give the
// average since each process started), as a share of the whole machine,
// so the rows add up to the bar's CPU number. Processes group by program
// (helium ×12); click a column to sort. Sampling runs only while the card
// is open. btop, at the bottom, has the full picture.
//
// Ending a program: hover a row for ✕, click it (the row turns red and the
// list holds still), click the row again. That asks the listed processes
// to quit (SIGTERM, so apps can save); if any are still there 3 seconds
// later the row offers Force quit (SIGKILL). Only your own processes, and
// never the desktop's own: the shared list below plus Wm.sessionProcs.
Popout {
    id: root

    property var groups: []        // every program: {name, count, cpu, rss, pids, killable}
    property string sortBy: "cpu"
    readonly property var rows: frozen ?? sorted(groups, sortBy).slice(0, maxRows)
    readonly property int maxRows: 8
    readonly property int rowHeight: 24

    property real memTotal: 0      // kB
    property real memAvail: 0
    property string load: ""
    property var prev: null        // last snapshot: {total, ticks: {pid: ticks}}

    // ending a program
    property string armed: ""      // name of the row waiting for its second click
    property var frozen: null      // the list as it was when armed, so rows don't move
    property var ending: ({})      // name → {pids, at, stuck}

    // processes every setup's session needs; Wm.sessionProcs adds the WM's own
    readonly property var sharedSessionProcs: /^(systemd|\(sd-pam\)|dbus-.*|pipewire.*|wireplumber|xdg-.*|gvfs.*|at-spi.*|dconf-service|gnome-keyring-daemon|ssh-agent|gpg-agent|lxpolkit|polkit-.*|dunst|qs|quickshell)$/

    cardWidth: 360
    cardHeight: col.implicitHeight + 2 * cardPadding

    // scriptable: qs -p ~/.config/mango/quickshell ipc call metrics toggle
    IpcHandler {
        target: "metrics"
        function toggle(): void { root.visible = !root.visible }
    }

    onVisibleChanged: {
        disarm()
        if (visible) {
            prev = null
            groups = []
            sampler.running = true
            // a quick second snapshot so the list fills almost at once
            tick.interval = 700
            tick.restart()
        } else {
            tick.stop()
        }
    }

    Timer {
        id: tick
        repeat: true
        onTriggered: {
            interval = 2000
            sampler.running = true
        }
    }

    Process {
        id: sampler
        command: [Theme.configDir + "/scripts/procs"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    function isSession(name) {
        return sharedSessionProcs.test(name) || Wm.sessionProcs.test(name)
    }

    function ingest(t) {
        let total = 0, me = ""
        const ticks = {}, procs = []
        for (const l of t.split("\n")) {
            const f = l.split("\t")
            if (f[0] === "cpu")
                total = Number(f[1])
            else if (f[0] === "mem") {
                memTotal = Number(f[1])
                memAvail = Number(f[2])
            } else if (f[0] === "load")
                load = f[1]
            else if (f[0] === "me")
                me = f[1]
            else if (f.length === 5) {
                ticks[f[0]] = Number(f[1])
                procs.push({ pid: f[0], rss: Number(f[2]), uid: f[3], name: f[4] })
            }
        }
        if (prev && total > prev.total) {
            const dt = total - prev.total
            const byName = {}
            for (const p of procs) {
                let g = byName[p.name]
                if (!g)
                    g = byName[p.name] = { name: p.name, count: 0, cpu: 0, rss: 0, pids: [],
                                           killable: !isSession(p.name) }
                g.count++
                g.rss += p.rss
                g.pids.push(p.pid)
                // anyone else's process in the group (root, a service
                // user) and the group can't be ended from here
                if (p.uid !== me)
                    g.killable = false
                // new since the last snapshot: no baseline yet, counts 0
                if (p.pid in prev.ticks)
                    g.cpu += 100 * Math.max(0, ticks[p.pid] - prev.ticks[p.pid]) / dt
            }
            groups = Object.values(byName)
        }
        prev = { total: total, ticks: ticks }

        // programs being ended: drop the ones that are gone, and flag the
        // ones still running 3s after SIGTERM for a Force quit
        const next = {}
        for (const name in ending) {
            const e = ending[name]
            const alive = e.pids.filter(p => p in ticks)
            if (alive.length)
                next[name] = { pids: alive, at: e.at, stuck: Date.now() - e.at >= 3000 }
        }
        ending = next
    }

    function sorted(list, key) {
        return list.slice().sort((a, b) => b[key] - a[key] || b.rss - a.rss)
    }

    function mem(kb) {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M"
    }

    function arm(g) {
        frozen = rows
        armed = g.name
        disarmTimer.restart()
    }

    function disarm() {
        armed = ""
        frozen = null
        disarmTimer.stop()
    }

    function end(g) {
        disarm()
        Quickshell.execDetached(["kill", "-s", "TERM"].concat(g.pids))
        const next = Object.assign({}, ending)
        next[g.name] = { pids: g.pids, at: Date.now(), stuck: false }
        ending = next
    }

    function forceQuit(name) {
        const e = ending[name]
        if (e)
            Quickshell.execDetached(["kill", "-s", "KILL"].concat(e.pids))
    }

    Timer {
        id: disarmTimer
        interval: 4000
        onTriggered: root.disarm()
    }

    function openBtop() {
        root.visible = false
        Quickshell.execDetached(["sh", "-c",
            "command -v btop >/dev/null && exec kitty -e btop || " +
            "notify-send -a quickshell 'btop is not installed' 'sudo apt install btop'"])
    }

    // label · bar · value · detail
    component Meter: Item {
        property string tag
        property color tint
        property real value          // 0..100
        property string detail

        width: parent.width
        height: 20

        Text {
            id: meterTag
            width: 40
            anchors.verticalCenter: parent.verticalCenter
            text: parent.tag
            color: parent.tint
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: true
        }
        Rectangle {
            id: track
            anchors.left: meterTag.right
            anchors.right: meterValue.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Qt.alpha(Theme.fg, 0.1)

            Rectangle {
                width: Math.min(Math.max(parent.parent.value, 0), 100) / 100 * parent.width
                height: parent.height
                radius: 3
                color: parent.parent.tint
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
        Text {
            id: meterValue
            width: 36
            anchors.right: meterDetail.left
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Math.round(parent.value) + "%"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
        Text {
            id: meterDetail
            width: 92
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: parent.detail
            color: Qt.alpha(Theme.fg, 0.5)
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    // column header that sorts on click
    component SortHeader: Text {
        property string key
        text: key.toUpperCase() + (root.sortBy === key ? " ▾" : "")
        color: root.sortBy === key ? Theme.accent : Qt.alpha(Theme.fg, 0.45)
        horizontalAlignment: Text.AlignRight
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.bold: true

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.disarm()
                root.sortBy = parent.key
            }
        }
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Meter {
            tag: "CPU"
            tint: Theme.red
            // the bar's own number, so card and bar always agree
            value: Sys.cpu
            detail: root.load !== "" ? "load " + root.load : ""
        }
        Meter {
            tag: "RAM"
            tint: Theme.blue
            value: root.memTotal > 0 ? 100 * (1 - root.memAvail / root.memTotal) : Sys.mem
            detail: root.memTotal > 0
                ? root.mem(root.memTotal - root.memAvail) + " / " + root.mem(root.memTotal) : ""
        }

        Item {
            width: parent.width
            height: 18

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "PROGRAM"
                color: Qt.alpha(Theme.fg, 0.45)
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
            }
            SortHeader {
                key: "cpu"
                width: 56
                anchors.right: memHeader.left
                anchors.verticalCenter: parent.verticalCenter
            }
            SortHeader {
                id: memHeader
                key: "rss"
                text: "MEM" + (root.sortBy === "rss" ? " ▾" : "")
                width: 64
                anchors.right: parent.right
                anchors.rightMargin: 30
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // fixed height: the card doesn't jump while the list fills or sorts
        Item {
            width: parent.width
            height: root.maxRows * root.rowHeight

            Text {
                anchors.centerIn: parent
                visible: root.rows.length === 0
                text: "sampling…"
                color: Qt.alpha(Theme.fg, 0.4)
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Column {
                width: parent.width

                Repeater {
                    model: root.rows

                    Item {
                        id: row
                        required property var modelData
                        readonly property bool armed: root.armed === modelData.name
                        readonly property var endingState: root.ending[modelData.name] ?? null
                        width: parent.width
                        height: root.rowHeight

                        // hover (and the second click once armed); declared
                        // first so the ✕ and Force quit buttons sit above it
                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (row.armed) root.end(row.modelData)
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: 5
                            visible: row.armed
                            color: Theme.red
                        }

                        // share of the top row's value in the sorted column
                        Rectangle {
                            readonly property real peak: root.rows[0]?.[root.sortBy] ?? 0
                            readonly property real v: row.modelData[root.sortBy]
                            visible: !row.armed
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - 4
                            radius: 5
                            width: peak > 0 && v > 0 ? Math.max(2, v / peak * (parent.width - 30)) : 0
                            color: Qt.alpha(root.sortBy === "cpu" ? Theme.red : Theme.blue, 0.12)
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }

                        // name, then a dim ×N when the program runs as several processes
                        Text {
                            id: nameText
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth,
                                            cpuText.x - x - 8 - (countText.visible ? countText.implicitWidth + 6 : 0))
                            elide: Text.ElideRight
                            text: row.armed ? "End " + row.modelData.name + "?" : row.modelData.name
                            color: row.armed ? Theme.bg
                                 : row.endingState ? Qt.alpha(Theme.fg, 0.45) : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: row.armed
                        }
                        Text {
                            id: countText
                            anchors.left: nameText.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.count > 1
                            text: "×" + row.modelData.count
                            color: row.armed ? Theme.bg : Qt.alpha(Theme.fg, 0.4)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        // armed: what the second click does, over the number columns
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.armed
                            text: "click again to quit it"
                            color: Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            id: cpuText
                            width: 56
                            anchors.right: memText.left
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            visible: !row.armed && !row.endingState
                            text: row.modelData.cpu.toFixed(1)
                            color: row.modelData.cpu >= 10 ? Theme.red : Qt.alpha(Theme.fg, 0.85)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            id: memText
                            width: 64
                            anchors.right: parent.right
                            anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            visible: !row.armed && !row.endingState
                            text: root.mem(row.modelData.rss)
                            color: Qt.alpha(Theme.fg, 0.85)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }

                        // SIGTERM sent: waiting, then Force quit if it's still around
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!row.endingState && !row.endingState.stuck
                            text: "quitting…"
                            color: Qt.alpha(Theme.fg, 0.45)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.italic: true
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!row.endingState && row.endingState.stuck
                            width: forceText.implicitWidth + 16
                            height: parent.height - 4
                            radius: 5
                            color: forceMa.containsMouse ? Theme.red : Qt.alpha(Theme.red, 0.2)

                            Text {
                                id: forceText
                                anchors.centerIn: parent
                                text: "Force quit"
                                color: forceMa.containsMouse ? Theme.bg : Theme.red
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                id: forceMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.forceQuit(row.modelData.name)
                            }
                        }

                        // ✕ on hover, only for programs this card may end
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.killable && !row.armed && !row.endingState
                                     && (rowMa.containsMouse || xMa.containsMouse)
                            width: 20
                            height: 20
                            radius: 5
                            color: xMa.containsMouse ? Qt.alpha(Theme.red, 0.25) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: xMa.containsMouse ? Theme.red : Qt.alpha(Theme.fg, 0.5)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: xMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.arm(row.modelData)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.fg, 0.15)
        }

        Rectangle {
            width: parent.width
            height: 30
            radius: 8
            color: btopMa.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍛"
                    color: Theme.cyan
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "open btop"
                    color: Qt.alpha(Theme.fg, 0.9)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            MouseArea {
                id: btopMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openBtop()
            }
        }
    }
}
