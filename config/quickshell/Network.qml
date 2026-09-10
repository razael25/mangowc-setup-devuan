import QtQuick
import Quickshell

// Active connection indicator (icon-only; connection details live in
// the network app). Click toggles the quickshell network app; right
// click opens nm-connection-editor for the deep settings it doesn't
// cover.
BarModule {
    id: root

    icon: Sys.netIcon
    iconColor: Sys.vpnOn ? Theme.green : Sys.online ? Theme.cyan : Theme.red

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            Quickshell.execDetached(["nm-connection-editor"])
        else
            Quickshell.execDetached([Theme.configDir + "/scripts/network"])
    }
}
