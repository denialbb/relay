// RelayMetrics.qml — shared spacing, radius, and animation metrics adapted to Omarchy qs.Commons Style.
import QtQuick
import qs.Commons

QtObject {
    id: root

    property int spacingXS: (typeof Style !== "undefined" && Style && Style.space) ? Style.space(4) : 4
    property int spacingSM: (typeof Style !== "undefined" && Style && Style.space) ? Style.space(8) : 8
    property int spacingMD: (typeof Style !== "undefined" && Style && Style.space) ? Style.space(12) : 12
    property int spacingLG: (typeof Style !== "undefined" && Style && Style.space) ? Style.space(16) : 16
    property int spacingXL: (typeof Style !== "undefined" && Style && Style.space) ? Style.space(24) : 24

    property int radiusSM: (typeof Style !== "undefined" && Style && typeof Style.cornerRadius === "number" && Style.cornerRadius > 0)
        ? Math.max(2, Math.round(Style.cornerRadius * 0.5)) : 4
    property int radiusMD: (typeof Style !== "undefined" && Style && typeof Style.cornerRadius === "number" && Style.cornerRadius > 0)
        ? Math.max(4, Style.cornerRadius) : 8
    property int radiusLG: (typeof Style !== "undefined" && Style && typeof Style.cornerRadius === "number" && Style.cornerRadius > 0)
        ? Math.max(6, Math.round(Style.cornerRadius * 1.5)) : 12

    property int barHeight: (typeof Style !== "undefined" && Style && Style.space) ? Style.space(48) : 48

    property int animationFast: 120
    property int animationNormal: 200
    property int animationSlow: 300
}
