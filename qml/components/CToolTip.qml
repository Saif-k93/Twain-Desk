import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl as Impl
import QtQuick.Controls.FluentWinUI3
import QtQuick.Effects
import TwainDesk

ToolTip {
    id: control
    margins: 8
    palette.toolTipText: AppSettings.text
    delay: 100

    background: Item {
        antialiasing: AppSettings.quality
        MultiEffect {
            x: -control.leftInset
            y: -control.topInset
            width: source.width
            height: source.height
            source: Rectangle {
                width: control.background.width + control.leftInset + control.rightInset
                implicitHeight: 30
                antialiasing: AppSettings.quality
                height: control.background.height + control.topInset + control.bottomInset
                color: AppSettings.background
                border.width: 1
                border.color: AppSettings.isLight ? AppSettings.midlight : Impl.Color.transparent(AppSettings.shadow, 0.3)
                radius: 4
            }
            shadowOpacity: AppSettings.isLight ? 0.3 : 0.9
            shadowColor: AppSettings.shadow
            shadowEnabled: AppSettings.quality
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            blurMax: AppSettings.quality ? AppSettings.isDark ? 32 : 24 : 0
            blurEnabled: !AppSettings.isDark && AppSettings.quality
            blur: 0.1
        }
    }
}
