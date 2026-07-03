import bb.cascades 1.0

// Techy dark button: dark panel, accent bar on the left, bold uppercase label.
Container {
    id: b
    property string label: "BUTTON"
    property string accent: "#39d353"
    property bool on: true              // enabled-ish (Container has no usable 'enabled' for taps)
    signal clicked()

    horizontalAlignment: HorizontalAlignment.Fill
    background: Color.create("#0c111a")
    opacity: b.on ? 1.0 : 0.35
    layout: DockLayout {}

    // accent bar
    Container {
        horizontalAlignment: HorizontalAlignment.Left
        verticalAlignment: VerticalAlignment.Fill
        preferredWidth: 6
        background: Color.create(b.accent)
    }

    Label {
        horizontalAlignment: HorizontalAlignment.Center
        verticalAlignment: VerticalAlignment.Center
        topMargin: 22
        bottomMargin: 22
        text: b.label
        textStyle {
            color: b.on ? Color.White : Color.create("#5b6675")
            base: SystemDefaults.TextStyles.BodyText
            fontWeight: FontWeight.Bold
        }
    }

    gestureHandlers: [
        TapHandler { onTapped: { if (b.on) b.clicked() } }
    ]
}
