import QtQuick
import Quickshell
import Quickshell.Io

// Pending-updates indicator, presence-gated: hidden at zero, an icon +
// count pill when apt has upgrades. The check is root-free and lock-free
// (simulated dist-upgrade), polled hourly plus shortly after the upgrade
// terminal is opened; middle click re-checks now. The count is only as
// fresh as the last `apt update` — the upgrade terminal runs one, and
// APT::Periodic::Update-Package-Lists "1" makes the system do it daily.
BarModule {
    id: root

    property int count: 0
    visible: count > 0
    icon: "󰚰"
    iconColor: Theme.accent
    label: String(count)

    Process {
        id: checkProc
        command: ["sh", "-c",
            "apt-get -s -o Debug::NoLocking=1 dist-upgrade 2>/dev/null | grep -c '^Inst'"]
        stdout: StdioCollector {
            onStreamFinished: root.count = parseInt(text.trim()) || 0
        }
    }

    Timer {
        interval: 3600 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: checkProc.running = true
    }

    // the upgrade runs in a detached terminal — recheck a few minutes
    // after it was opened so the pill clears without waiting out the hour
    Timer {
        id: recheck
        interval: 5 * 60 * 1000
        onTriggered: checkProc.running = true
    }

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) {
            checkProc.running = true
        } else {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c",
                "sudo apt update && sudo apt full-upgrade; " +
                "printf '\\ndone - press enter to close '; read _"])
            recheck.restart()
        }
    }
}
