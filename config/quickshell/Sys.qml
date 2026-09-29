pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight system metrics: cpu/mem/disk on a 3s tick. Network follows
// `nmcli monitor` (connect, drop, VPN up, connectivity change show at once)
// plus a slow poll for Wi-Fi signal strength, which the monitor doesn't report.
Singleton {
    id: root

    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property bool hasBattery: false
    property real battery: 0
    property bool batteryCharging: false
    property string netName: ""
    property string netType: ""
    property bool vpnOn: false
    property string vpnName: ""
    property int wifiSignal: -1        // 0–100 while on Wi-Fi, -1 unknown
    // NetworkManager's verdict: full, limited, portal, none or unknown.
    // Real only while its connectivity check is on (Debian's
    // network-manager-config-connectivity-debian); without it NM just
    // says full.
    property string connectivity: "unknown"
    property string checkUri: ""       // the check's URL: a sign-in page intercepts it

    readonly property bool wireless: netType.indexOf("wireless") !== -1
    readonly property string netIcon: vpnOn ? "󰦝"
        : wireless ? (wifiSignal < 0 ? "󰤨" : wifiSignal < 20 ? "󰤯" : wifiSignal < 40 ? "󰤟"
                      : wifiSignal < 60 ? "󰤢" : wifiSignal < 80 ? "󰤥" : "󰤨")
        : netType.indexOf("ethernet") !== -1 ? "󰈀"
        : "󰤭"
    readonly property bool online: netName !== ""
    // connected, but the network wants a login page first (hotel, café)
    readonly property bool signInNeeded: online && connectivity === "portal"
    // connected to something that doesn't reach the internet
    readonly property bool noInternet: online && (connectivity === "limited" || connectivity === "none")

    property var _prev: ({ idle: 0, total: 0 })

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    Process {
        id: statProc
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; df --output=pcent / | tail -1; " +
            "for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] && echo \"BAT $(cat \"$b/capacity\") $(cat \"$b/status\")\" && break; done; true"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStat(text)
        }
    }

    function parseStat(t) {
        const lines = t.trim().split("\n")
        let memTotal = 0, memAvail = 0, foundBattery = false
        for (const line of lines) {
            if (line.startsWith("cpu ")) {
                const f = line.trim().split(/\s+/).slice(1).map(Number)
                const idle = f[3] + (f[4] || 0)
                const total = f.reduce((a, b) => a + b, 0)
                const dIdle = idle - _prev.idle
                const dTotal = total - _prev.total
                if (_prev.total > 0 && dTotal > 0)
                    cpu = Math.max(0, Math.min(100, 100 * (1 - dIdle / dTotal)))
                _prev = { idle: idle, total: total }
            } else if (line.startsWith("MemTotal:")) {
                memTotal = parseInt(line.split(/\s+/)[1])
            } else if (line.startsWith("MemAvailable:")) {
                memAvail = parseInt(line.split(/\s+/)[1])
            } else if (line.startsWith("BAT ")) {
                const parts = line.split(/\s+/)
                foundBattery = true
                battery = parseInt(parts[1])
                batteryCharging = parts[2] === "Charging"
            } else if (line.indexOf("%") !== -1) {
                disk = parseInt(line)
            }
        }
        if (memTotal > 0)
            mem = 100 * (1 - memAvail / memTotal)
        hasBattery = foundBattery
    }

    property bool capsOn: false
    property bool dndOn: false
    property bool micMuted: false
    // Wayland popups are xdg-popups sized to their card; Popout's
    // fullscreen click-catcher mode (for bare X11) is never wanted here
    readonly property bool composited: false

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: capsProc.running = true
    }

    // one process per tick covers the indicators: caps lock (keyboard
    // LED state via sysfs — no X server to ask) + dunst paused +
    // default-source mute. Each field is one guaranteed line.
    Process {
        id: capsProc
        command: ["sh", "-c",
            "c=0; for l in /sys/class/leds/*capslock/brightness; do " +
            "[ -r \"$l\" ] && [ \"$(cat \"$l\")\" != 0 ] && c=1; done; echo $c; " +
            "dunstctl is-paused 2>/dev/null || echo false; " +
            "pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null || echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.capsOn = lines[0] === "1"
                root.dndOn = lines[1] === "true"
                root.micMuted = lines[2] === "Mute: yes"
            }
        }
    }

    // fast re-poll so the icon settles right after a toggle instead of
    // waiting out (or fighting) the 1s tick
    Timer {
        id: dndRefresh
        interval: 300
        onTriggered: capsProc.running = true
    }

    function toggleMicMute() {
        Quickshell.execDetached(["pactl", "set-source-mute",
                                 "@DEFAULT_SOURCE@", "toggle"])
        micMuted = !micMuted
        dndRefresh.restart()
    }

    function toggleDnd() {
        Quickshell.execDetached(["dunstctl", "set-paused", "toggle"])
        dndOn = !dndOn
        dndRefresh.restart()
    }
    function popNotification() {
        // replaying must always show something: leave DND first, and say so
        // when the history is empty instead of silently doing nothing
        Quickshell.execDetached(["sh", "-c",
            "dunstctl set-paused false; " +
            "if [ \"$(dunstctl count history)\" -eq 0 ]; then " +
            "notify-send -a dunst -t 2000 'Notifications' 'History is empty'; " +
            "else dunstctl history-pop; fi"])
        dndRefresh.restart()
    }

    // every change NetworkManager announces → one refresh (debounced: a
    // connect fires a burst of lines)
    Process {
        id: netMonitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: line => netDebounce.restart()
        }
        onExited: netMonitorRetry.restart()
    }
    Timer {
        id: netMonitorRetry
        interval: 5000
        onTriggered: netMonitor.running = true
    }
    Timer {
        id: netDebounce
        interval: 300
        onTriggered: netProc.running = true
    }
    // signal strength isn't announced: poll it on Wi-Fi, and keep a slow
    // safety poll otherwise
    Timer {
        interval: root.wireless ? 15000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    // primary transport + vpn tracked separately: a vpn/wireguard/tun
    // connection rides ON a transport, it isn't one. One process, four
    // sections: active connections, connectivity, the in-use AP's signal
    // (cached scan, no rescan), the connectivity check URL.
    Process {
        id: netProc
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE connection show --active; echo ===; " +
            "nmcli networking connectivity; echo ===; " +
            "nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null | grep '^\\*' | head -1; echo ===; " +
            "busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager " +
            "org.freedesktop.NetworkManager ConnectivityCheckUri 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("===\n")
                let name = "", type = "", vName = "", vOn = false
                for (const line of (parts[0] ?? "").trim().split("\n")) {
                    const i = line.lastIndexOf(":")
                    if (i <= 0)
                        continue
                    const n = line.slice(0, i), t = line.slice(i + 1)
                    if (t === "loopback")
                        continue
                    if (t === "vpn" || t === "wireguard" || t === "tun") {
                        vOn = true
                        vName = n
                    } else if (name === "") {
                        name = n
                        type = t
                    }
                }
                root.netName = name
                root.netType = type
                root.vpnOn = vOn
                root.vpnName = vName
                root.connectivity = (parts[1] ?? "").trim() || "unknown"
                const sig = parseInt((parts[2] ?? "").trim().split(":")[1])
                root.wifiSignal = type.indexOf("wireless") !== -1 && !isNaN(sig) ? sig : -1
                const uri = (parts[3] ?? "").match(/"(.*)"/)
                root.checkUri = uri ? uri[1] : ""
            }
        }
    }
}
