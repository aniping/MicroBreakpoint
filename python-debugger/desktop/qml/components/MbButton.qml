import QtQuick
import QtQuick.Controls

Button {
    id: control

    property var appTheme
    property string variant: "neutral"
    property string iconText: ""

    implicitWidth: Math.max(104, contentRow.implicitWidth + 34)
    implicitHeight: 36
    padding: 0
    font.pixelSize: 13
    font.weight: Font.DemiBold

    onHoveredChanged: iconCanvas.requestPaint()
    onPressedChanged: iconCanvas.requestPaint()
    onEnabledChanged: iconCanvas.requestPaint()
    onIconTextChanged: iconCanvas.requestPaint()

    function accentColor() {
        if (variant === "primary") return appTheme.primary
        if (variant === "success") return appTheme.success
        if (variant === "warning") return appTheme.warning
        if (variant === "danger") return appTheme.danger
        if (variant === "ghost") return appTheme.textMuted
        return appTheme.textMuted
    }

    function backgroundColor() {
        if (!enabled) return appTheme.panelBgAlt
        if (variant === "ghost") return hovered ? appTheme.panelHover : "transparent"
        if (pressed) return appTheme.panelActive
        if (hovered) return appTheme.panelHover
        if (variant === "primary") return appTheme.primarySoft
        if (variant === "success") return appTheme.successSoft
        if (variant === "warning") return appTheme.warningSoft
        if (variant === "danger") return appTheme.dangerSoft
        return appTheme.inputBg
    }

    function foregroundColor() {
        if (!enabled) return appTheme.textDisabled
        if (variant === "primary") return appTheme.primary
        if (variant === "success") return appTheme.success
        if (variant === "warning") return appTheme.warning
        if (variant === "danger") return appTheme.danger
        return appTheme.textStrong
    }

    function iconBackgroundColor() {
        if (!enabled) return appTheme.panelBg
        if (variant === "primary") return appTheme.primarySoft
        if (variant === "success") return appTheme.successSoft
        if (variant === "warning") return appTheme.warningSoft
        if (variant === "danger") return appTheme.dangerSoft
        return appTheme.panelBgAlt
    }

    function borderColor() {
        if (!enabled) return appTheme.borderSoft
        if (variant === "ghost") return "transparent"
        if (variant === "primary" || variant === "success" || variant === "warning" || variant === "danger") return accentColor()
        return appTheme.border
    }

    contentItem: Item {
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: control.iconText.length > 0 ? 9 : 0

            Rectangle {
                visible: control.iconText.length > 0
                width: 20
                height: 20
                radius: 5
                color: control.iconBackgroundColor()
                border.color: control.enabled ? control.borderColor() : control.appTheme.borderSoft
                anchors.verticalCenter: parent.verticalCenter

                Canvas {
                    id: iconCanvas
                    anchors.fill: parent
                    anchors.margins: 4

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width
                        var h = height
                        var icon = control.iconText
                        ctx.clearRect(0, 0, w, h)
                        ctx.strokeStyle = control.foregroundColor()
                        ctx.fillStyle = control.foregroundColor()
                        ctx.lineWidth = 1.8
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"

                        if (icon === "+" || icon === "新增") {
                            ctx.beginPath()
                            ctx.moveTo(w * 0.5, h * 0.22)
                            ctx.lineTo(w * 0.5, h * 0.78)
                            ctx.moveTo(w * 0.22, h * 0.5)
                            ctx.lineTo(w * 0.78, h * 0.5)
                            ctx.stroke()
                        } else if (icon === "×" || icon === "x" || icon === "X") {
                            ctx.beginPath()
                            ctx.moveTo(w * 0.25, h * 0.25)
                            ctx.lineTo(w * 0.75, h * 0.75)
                            ctx.moveTo(w * 0.75, h * 0.25)
                            ctx.lineTo(w * 0.25, h * 0.75)
                            ctx.stroke()
                        } else if (icon === "▶" || icon === ">") {
                            ctx.beginPath()
                            ctx.moveTo(w * 0.33, h * 0.22)
                            ctx.lineTo(w * 0.33, h * 0.78)
                            ctx.lineTo(w * 0.76, h * 0.5)
                            ctx.closePath()
                            ctx.fill()
                        } else if (icon === "■" || icon === "stop") {
                            ctx.fillRect(w * 0.28, h * 0.28, w * 0.44, h * 0.44)
                        } else if (icon === "↻" || icon === "↺") {
                            var clockwise = icon === "↻"
                            ctx.beginPath()
                            ctx.arc(w * 0.5, h * 0.5, Math.min(w, h) * 0.3, clockwise ? -0.4 : 0.4, clockwise ? Math.PI * 1.45 : -Math.PI * 1.45, !clockwise)
                            ctx.stroke()
                            ctx.beginPath()
                            if (clockwise) {
                                ctx.moveTo(w * 0.72, h * 0.26)
                                ctx.lineTo(w * 0.78, h * 0.48)
                                ctx.lineTo(w * 0.58, h * 0.42)
                            } else {
                                ctx.moveTo(w * 0.28, h * 0.26)
                                ctx.lineTo(w * 0.22, h * 0.48)
                                ctx.lineTo(w * 0.42, h * 0.42)
                            }
                            ctx.stroke()
                        } else if (icon === "●") {
                            ctx.beginPath()
                            ctx.arc(w * 0.5, h * 0.5, Math.min(w, h) * 0.24, 0, Math.PI * 2)
                            ctx.fill()
                        } else if (icon === "!") {
                            ctx.beginPath()
                            ctx.moveTo(w * 0.5, h * 0.22)
                            ctx.lineTo(w * 0.5, h * 0.58)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(w * 0.5, h * 0.76, 1.4, 0, Math.PI * 2)
                            ctx.fill()
                        } else {
                            ctx.beginPath()
                            ctx.arc(w * 0.5, h * 0.5, Math.min(w, h) * 0.24, 0, Math.PI * 2)
                            ctx.stroke()
                        }
                    }
                }
            }

            Text {
                text: control.text
                color: control.foregroundColor()
                font: control.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: Rectangle {
        radius: 4
        color: control.backgroundColor()
        border.color: control.borderColor()
        border.width: control.variant === "neutral" ? 1 : 1
    }
}
