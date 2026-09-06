// RelayTheme.qml — semantic theme roles adapted to Omarchy qs.Commons Color with clean fallbacks.
import QtQuick
import qs.Commons

QtObject {
    id: root

    readonly property color _defaultBackground: "#101315"
    readonly property color _defaultSurface: "#181b1d"
    readonly property color _defaultSurfaceRaised: "#222629"
    readonly property color _defaultBorder: "#2a2e32"
    readonly property color _defaultTextPrimary: "#cacccc"
    readonly property color _defaultTextSecondary: "#707880"
    readonly property color _defaultTextDisabled: "#40464c"
    readonly property color _defaultAccent: "#4d9de0"
    readonly property color _defaultSuccess: "#43a047"
    readonly property color _defaultWarning: "#e6a100"
    readonly property color _defaultError: "#e53935"

    property color background: (typeof Color !== "undefined" && Color && Color.background)
        ? Color.background : _defaultBackground

    property color surface: (typeof Color !== "undefined" && Color && Color.popups && Color.popups.background)
        ? Color.popups.background : _defaultSurface

    property color surfaceRaised: (typeof Color !== "undefined" && Color && Color.menu && Color.menu.background)
        ? Color.menu.background : _defaultSurfaceRaised

    property color border: (typeof Color !== "undefined" && Color && Color.popups && Color.popups.border)
        ? Color.popups.border : _defaultBorder

    property color textPrimary: (typeof Color !== "undefined" && Color && Color.foreground)
        ? Color.foreground : _defaultTextPrimary

    property color textSecondary: (typeof Color !== "undefined" && Color && Color.muted)
        ? Color.muted : _defaultTextSecondary

    property color textDisabled: (typeof Color !== "undefined" && Color && Color.muted)
        ? Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.5) : _defaultTextDisabled

    property color accent: (typeof Color !== "undefined" && Color && Color.accent)
        ? Color.accent : _defaultAccent

    property color success: (typeof Color !== "undefined" && Color && Color.success)
        ? Color.success : _defaultSuccess

    property color warning: (typeof Color !== "undefined" && Color && Color.warning)
        ? Color.warning : _defaultWarning

    property color error: (typeof Color !== "undefined" && Color && (Color.urgent || Color.error))
        ? (Color.urgent || Color.error) : _defaultError

    // Omarchy UI font (follows `omarchy font set` via Style.font); empty falls back to Qt default.
    property string fontFamily: (typeof Style !== "undefined" && Style && Style.font && Style.font.family)
        ? Style.font.family : ""
}
