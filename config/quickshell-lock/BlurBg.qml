import QtQuick
import QtQuick.Effects

// The wallpaper, blurred and dimmed (Qt's MultiEffect: qml6-module-qtquick-effects)
Item {
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.25
        saturation: -0.2
    }
}
