import QtQuick
import Quickshell
import Quickshell.Io

// Three-day forecast under the weather indicator — the calendar idiom:
// click the number, get the picture. Data comes from the same wttr.in
// fetch the bar module already makes; no extra requests.
// Settings live under the forecast: a location field (Enter pins it,
// "auto" unpins it) and °F/°C/auto. They write the weather-location and
// weather-units files Weather.qml watches, so a change refetches at once.
// Right-click on the module opens the card with the field focused.
Popout {
    id: root

    property string condition: ""
    property string feels: ""
    property string wind: ""
    property string place: ""
    property var days: []   // {label, glyph, hi, lo, rain}
    property bool failed: false   // last fetch failed (bad location, offline)

    // the saved settings, fed by Weather.qml ("" = auto)
    property string location: ""
    property string units: ""

    readonly property string locationFile: Theme.configDir + "/weather-location"
    readonly property string unitsFile: Theme.configDir + "/weather-units"
    readonly property bool localeF: Qt.locale().measurementSystem !== Locale.MetricSystem

    cardWidth: 300
    cardHeight: 268

    // scriptable: qs -p ~/.config/mango/quickshell ipc call weather toggle
    IpcHandler {
        target: "weather"
        function toggle(): void { root.visible = !root.visible }
    }

    onVisibleChanged: if (visible) field.text = location
    onLocationChanged: if (!field.activeFocus) field.text = location

    function openSettings() {
        visible = true
        // after Popout's own focus grab on open
        Qt.callLater(() => {
            field.forceActiveFocus()
            field.selectAll()
        })
    }

    // write or clear a settings file; the value goes in as an argument,
    // never spliced into the shell string
    function save(path, value) {
        if (value === "")
            Quickshell.execDetached(["rm", "-f", path])
        else
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"",
                                     "sh", value, path])
    }

    function saveLocation() {
        const v = field.text.trim()
        field.text = v
        if (v !== location)
            save(locationFile, v)
    }

    // where this forecast is for — also the tell when a VPN exit node is
    // fooling wttr.in's IP geolocation. A failed fetch says so here.
    Text {
        id: placeLine
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.place !== "" || root.failed
        text: root.failed
            ? "󰅙 couldn't get the weather" + (root.location !== "" ? " for \"" + root.location + "\"" : "")
            : "󰍎 " + root.place
        color: root.failed ? Theme.red : Qt.alpha(Theme.fg, 0.5)
        font.family: Theme.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    // current condition · feels like · wind
    Text {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: placeLine.visible ? placeLine.bottom : parent.top
        anchors.topMargin: placeLine.visible ? 4 : 0
        text: root.condition
            + (root.feels !== "" ? "  ·  feels " + root.feels + "°" : "")
            + (root.wind !== "" ? "  ·  󰖝 " + root.wind : "")
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
        elide: Text.ElideRight
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.bottom: settings.top
        anchors.bottomMargin: 12

        Repeater {
            model: root.days

            Column {
                id: day
                required property var modelData
                width: parent.width / Math.max(root.days.length, 1)
                spacing: 5

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.label
                    color: Qt.alpha(Theme.fg, 0.55)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.glyph
                    color: Theme.yellow
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: day.modelData.hi + "° / " + day.modelData.lo + "°"
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: day.modelData.rain >= 30
                    text: "󰖌 " + day.modelData.rain + "%"
                    color: Theme.cyan
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }

    Column {
        id: settings
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 8

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.fg, 0.15)
        }

        // location: type + Enter pins it; "auto" goes back to by-IP
        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: parent.width - (autoBtn.visible ? autoBtn.width + parent.spacing : 0)
                height: 30
                radius: 8
                color: Qt.alpha(Theme.fg, 0.06)
                border.width: 1
                border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.5) : "transparent"

                Text {
                    id: pin
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍎"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                // under the field, so a click on the text still places the cursor
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: field.forceActiveFocus()
                }

                TextInput {
                    id: field
                    anchors.left: pin.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Qt.alpha(Theme.accent, 0.4)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    selectByMouse: true
                    clip: true
                    onAccepted: {
                        root.saveLocation()
                        focus = false
                    }
                    // Escape drops an unsaved edit first, then closes (Popout)
                    Keys.onEscapePressed: event => {
                        if (text !== root.location)
                            text = root.location
                        else
                            event.accepted = false
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "auto (by IP) · type a city or zip"
                        color: Qt.alpha(Theme.fg, 0.35)
                        font: field.font
                    }
                }
            }

            Rectangle {
                id: autoBtn
                visible: root.location !== ""
                width: autoText.implicitWidth + 16
                height: 30
                radius: 8
                color: autoMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)

                Text {
                    id: autoText
                    anchors.centerIn: parent
                    text: "auto"
                    color: Qt.alpha(Theme.fg, 0.8)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                MouseArea {
                    id: autoMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        field.text = ""
                        root.save(root.locationFile, "")
                    }
                }
            }
        }

        // units: auto (from the locale) / °F / °C
        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    { value: "", label: "auto · " + (root.localeF ? "°F" : "°C") },
                    { value: "f", label: "°F" },
                    { value: "c", label: "°C" }
                ]

                Rectangle {
                    id: seg
                    required property var modelData
                    readonly property bool active: root.units === modelData.value
                    width: (parent.width - 2 * parent.spacing) / 3
                    height: 26
                    radius: 8
                    color: active ? Theme.accent
                         : segMa.containsMouse ? Qt.alpha(Theme.fg, 0.14) : Qt.alpha(Theme.fg, 0.06)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        color: seg.active ? Theme.bg : Qt.alpha(Theme.fg, 0.8)
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: seg.active
                    }

                    MouseArea {
                        id: segMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.save(root.unitsFile, seg.modelData.value)
                    }
                }
            }
        }
    }
}
