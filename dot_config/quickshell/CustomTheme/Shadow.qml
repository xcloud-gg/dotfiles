import QtQuick
import QtQuick.Effects

// Drop-in replacement for QtQuick.Effects' RectangularShadow, which needs
// Qt 6.9 (Debian 13 ships 6.8.2). A rounded rectangle in the shadow color,
// blurred by MultiEffect -- same inputs (anchors/radius/blur/color) as the
// RectangularShadow uses it replaces. Needs a GPU scene graph backend: under
// QT_QUICK_BACKEND=software MultiEffect draws nothing, so there is simply no
// shadow there.
Item {
    id: shadow
    property real radius: 0
    property real blur: 15
    property color color: Qt.rgba(0, 0, 0, 0.4)

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: shadow.radius
        color: shadow.color
        visible: false
    }

    MultiEffect {
        anchors.fill: shape
        source: shape
        blurEnabled: true
        blur: 1.0
        blurMax: Math.max(1, Math.round(shadow.blur * 2))
        autoPaddingEnabled: true
    }
}
