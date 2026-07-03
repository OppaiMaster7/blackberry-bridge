import bb.cascades 1.0

// A single square-ish launcher tile. Reused for both Online and Offline modes.
Container {
    id: tile
    property string title: "Tile"
    property string accent: "#1f6feb"
    property string target: ""
    signal tapped(string title, string target)

    preferredWidth: 300
    preferredHeight: 200
    rightMargin: 12
    bottomMargin: 12
    background: Color.create(tile.accent)
    layout: DockLayout {}

    Label {
        horizontalAlignment: HorizontalAlignment.Center
        verticalAlignment: VerticalAlignment.Center
        text: tile.title
        multiline: true
        textStyle {
            color: Color.White
            base: SystemDefaults.TextStyles.SubtitleText
            fontWeight: FontWeight.Bold
            textAlign: TextAlign.Center
        }
    }

    gestureHandlers: [
        TapHandler {
            onTapped: tile.tapped(tile.title, tile.target)
        }
    ]
}
