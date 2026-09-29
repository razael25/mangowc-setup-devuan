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
Popout {
    id: root

    property var groups: []        // every program: {name, count, cpu, rss}
    property string sortBy: "cpu"
    readonly property var rows: sorted(groups, sortBy).slice(0, maxRows)
    readonly property int maxRows: 8
    readonly property int rowHeight: 24

    property real memTotal: 0      // kB
    property real memAvail: 0
    property string load: ""
    property var prev: null        // last snapshot: {total, ticks: {pid: ticks}}

    cardWidth: 360
    cardHeight: col.implicitHeight + 2 * cardPadding

    // scriptable: qs -p ~/.config/mango/quickshell ipc call metrics toggle
    IpcHandler {
        target: "metrics"
        function toggle(): void { root.visible = !root.visible }
    }

    onVisibleChanged: {
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

    function ingest(t) {
        let total = 0
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
            else if (f.length === 4) {
                ticks[f[0]] = Number(f[1])
                procs.push({ pid: f[0], rss: Number(f[2]), name: f[3] })
            }
        }
        if (prev && total > prev.total) {
            const dt = total - prev.total
            const byName = {}
            for (const p of procs) {
                let g = byName[p.name]
                if (!g)
                    g = byName[p.name] = { name: p.name, count: 0, cpu: 0, rss: 0 }
                g.count++
                g.rss += p.rss
                // new since the last snapshot: no baseline yet, counts 0
                if (p.pid in prev.ticks)
                    g.cpu += 100 * Math.max(0, ticks[p.pid] - prev.ticks[p.pid]) / dt
            }
            groups = Object.values(byName)
        }
        prev = { total: total, ticks: ticks }
    }

    function sorted(list, key) {
        return list.slice().sort((a, b) => b[key] - a[key] || b.rss - a.rss)
    }

    function mem(kb) {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G" : Math.round(kb / 1024) + "M"
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
            onClicked: root.sortBy = parent.key
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
                anchors.rightMargin: 8
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
                        width: parent.width
                        height: root.rowHeight

                        // share of the top row's value in the sorted column
                        Rectangle {
                            readonly property real peak: root.rows[0]?.[root.sortBy] ?? 0
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - 4
                            radius: 5
                            readonly property real v: row.modelData[root.sortBy]
                            width: peak > 0 && v > 0 ? Math.max(2, v / peak * parent.width) : 0
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
                            text: row.modelData.name
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            id: countText
                            anchors.left: nameText.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.count > 1
                            text: "×" + row.modelData.count
                            color: Qt.alpha(Theme.fg, 0.4)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            id: cpuText
                            width: 56
                            anchors.right: memText.left
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: row.modelData.cpu.toFixed(1)
                            color: row.modelData.cpu >= 10 ? Theme.red : Qt.alpha(Theme.fg, 0.85)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            id: memText
                            width: 64
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: root.mem(row.modelData.rss)
                            color: Qt.alpha(Theme.fg, 0.85)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
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
