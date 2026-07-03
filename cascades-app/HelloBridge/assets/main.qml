import bb.cascades 1.0

// 720x720-aware: centered content, full-bleed dark background, square-friendly.
Page {
    Container {
        layout: DockLayout {}
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        background: Color.create("#15181c")

        Container {
            horizontalAlignment: HorizontalAlignment.Center
            verticalAlignment: VerticalAlignment.Center
            layout: StackLayout {}

            Label {
                horizontalAlignment: HorizontalAlignment.Center
                text: "BlackBerry Bridge"
                textStyle {
                    color: Color.create("#e7c200")
                    base: SystemDefaults.TextStyles.TitleText
                }
            }
            Label {
                horizontalAlignment: HorizontalAlignment.Center
                text: "build → deploy → run: alive"
                textStyle {
                    color: Color.create("#cfd2d6")
                    base: SystemDefaults.TextStyles.BodyText
                }
            }
            Label {
                horizontalAlignment: HorizontalAlignment.Center
                text: "720 × 720 terminal"
                textStyle {
                    color: Color.create("#7d8590")
                    base: SystemDefaults.TextStyles.SmallText
                }
            }
        }
    }
}
