import bb.cascades 1.0

// BlackBerry Bridge — discover -> pair -> link -> live mirror.
Page {
    id: root
    property bool mirroring: false
    property bool userDisconnected: false      // DISCONNECT pressed -> stop auto-launching
    // "connecting" flashes by every 5s poll; treat it as still-online so nothing flickers
    property variant accent: conn.status === "offline" ? Color.create("#f85149")
                           : conn.paired                ? Color.create("#39d353")
                           :                              Color.create("#e3b341")

    // Auto-launch: the moment the paired host is reachable, start the mirror hands-free.
    // (Property-change trick: QML can't attach to conn.statusChanged directly in Cascades.)
    property string linkStatus: conn.status
    onLinkStatusChanged: {
        // key on mirror.active (not root.mirroring): if the client ever stops itself,
        // the next successful link probe relaunches the mirror automatically
        if (linkStatus === "connected" && !mirror.active && !root.userDisconnected) {
            root.mirroring = true;
            mirror.start(conn.host, 5900);
        }
    }

    Container {
        layout: DockLayout {}
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        background: Color.create("#06080c")

        // ===================== HOME =====================
        ScrollView {
            visible: !root.mirroring && !mirror.active
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill

            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 26; rightPadding: 26; topPadding: 24; bottomPadding: 26
                layout: StackLayout {}

                Label {
                    horizontalAlignment: HorizontalAlignment.Center
                    text: "B L A C K B E R R Y   B R I D G E"
                    textStyle { color: Color.create("#3d4757"); base: SystemDefaults.TextStyles.SmallText; fontWeight: FontWeight.Bold }
                }

                Label {
                    text: "HOSTS ON NETWORK"
                    topMargin: 18; bottomMargin: 8
                    textStyle { color: Color.create("#2b3340"); base: SystemDefaults.TextStyles.SmallText; fontWeight: FontWeight.Bold }
                }

                ListView {
                    preferredHeight: 200
                    dataModel: hosts
                    onTriggered: {
                        var d = dataModel.data(indexPath);
                        conn.selectHost(d.ip, d.port, d.name);
                    }
                    listItemComponents: [
                        ListItemComponent {
                            Container {
                                leftPadding: 18; rightPadding: 18; topPadding: 16; bottomPadding: 16; bottomMargin: 4
                                background: Color.create("#0c111a")
                                layout: StackLayout {}
                                Label { text: ListItemData.name; textStyle { color: Color.White; base: SystemDefaults.TextStyles.BodyText; fontWeight: FontWeight.Bold } }
                                Label { text: ListItemData.ip + " : " + ListItemData.port; textStyle { color: Color.create("#5b6675"); base: SystemDefaults.TextStyles.SmallText } }
                            }
                        }
                    ]
                }

                TButton {
                    topMargin: 8
                    label: conn.scanning ? "SEARCHING…" : "SCAN FOR HOSTS"
                    accent: "#22d3ee"
                    on: !conn.scanning
                    onClicked: conn.scan()
                }

                Container {
                    topMargin: 10
                    layout: StackLayout { orientation: LayoutOrientation.LeftToRight }
                    TextField {
                        id: manualIp
                        layoutProperties: StackLayoutProperties { spaceQuota: 1 }
                        hintText: "host IP (manual)"
                    }
                    TButton {
                        label: "ADD"; accent: "#6e7681"; leftMargin: 8; preferredWidth: 150
                        onClicked: { if (manualIp.text.length > 0) conn.selectHost(manualIp.text, 3389, manualIp.text) }
                    }
                }

                // link console
                Container {
                    horizontalAlignment: HorizontalAlignment.Fill
                    topMargin: 18
                    background: Color.create("#0c111a")
                    layout: StackLayout {}
                    Container { horizontalAlignment: HorizontalAlignment.Fill; preferredHeight: 6; background: root.accent }
                    Container {
                        leftPadding: 28; rightPadding: 28; topPadding: 22; bottomPadding: 24
                        layout: StackLayout {}
                        Container {
                            layout: StackLayout { orientation: LayoutOrientation.LeftToRight }
                            Label { verticalAlignment: VerticalAlignment.Center; rightMargin: 12; text: "●"; textStyle { base: SystemDefaults.TextStyles.TitleText; color: root.accent } }
                            Label {
                                verticalAlignment: VerticalAlignment.Center
                                text: conn.status === "offline" ? "LINK DOWN" : conn.paired ? "LINK ONLINE" : "PROBING…"
                                textStyle { color: Color.White; base: SystemDefaults.TextStyles.TitleText; fontWeight: FontWeight.Bold }
                            }
                        }
                        Label {
                            topMargin: 10
                            text: conn.paired ? (conn.hostName + "   " + conn.host + ":" + conn.port) : "no host paired — tap one above"
                            textStyle { color: Color.create("#8b949e"); base: SystemDefaults.TextStyles.SmallText }
                        }
                    }
                }

                TButton {
                    topMargin: 16
                    label: "LAUNCH MIRROR"
                    accent: "#39d353"
                    // paired is stable — binding to status=="connected" greyed this button
                    // out on every 5s background probe
                    on: conn.paired && conn.status !== "offline"
                    onClicked: { root.userDisconnected = false; root.mirroring = true; mirror.start(conn.host, 5900) }
                }
                TButton {
                    topMargin: 10
                    label: "RECONNECT"
                    accent: "#e3b341"
                    on: conn.paired && conn.status !== "connecting"
                    onClicked: conn.refresh()
                }
            }
        }

        // ===================== MIRROR =====================
        Container {
            visible: root.mirroring || mirror.active
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            background: Color.create("#000000")
            layout: DockLayout {}

            // live Android feed — raw pixels set directly from C++ (via objectName), no PNG, so
            // it updates instantly with no flashing. Touches are forwarded to the host as VNC
            // pointer events. The Android screen is SQUARE (720x720) but this ImageView fills a
            // taller device, so the image is AspectFit-letterboxed: the displayed image is a
            // centered square of side min(w,h). We map the touch into THAT square, so taps land
            // exactly where you press regardless of the device's real screen size.
            ImageView {
                id: feedView
                objectName: "feed"
                horizontalAlignment: HorizontalAlignment.Fill
                verticalAlignment: VerticalAlignment.Fill
                scalingMethod: ScalingMethod.AspectFit
                visible: mirror.streaming
                attachedObjects: [
                    // Cascades controls do NOT expose their real size as width/height QML
                    // properties — the old mapping divided by undefined and every touch
                    // landed off-target. This handler reports the true laid-out frame.
                    LayoutUpdateHandler {
                        id: feedLayout
                    }
                ]
                onTouch: {
                    var vw = feedLayout.layoutFrame.width;
                    var vh = feedLayout.layoutFrame.height;
                    if (vw <= 0 || vh <= 0) return;
                    var disp = Math.min(vw, vh);          // side of the AspectFit square
                    var offX = (vw - disp) / 2.0;         // left letterbox bar
                    var offY = (vh - disp) / 2.0;         // top  letterbox bar
                    var nx = (event.localX - offX) / disp;
                    var ny = (event.localY - offY) / disp;
                    if (nx < 0) nx = 0; else if (nx > 1) nx = 1;
                    if (ny < 0) ny = 0; else if (ny > 1) ny = 1;
                    if (event.touchType == TouchType.Down || event.touchType == TouchType.Move)
                        mirror.pointer(nx, ny, true);
                    else mirror.pointer(nx, ny, false);
                }
            }

            // status overlay (shown until a mirror source streams frames)
            Container {
                visible: !mirror.streaming
                horizontalAlignment: HorizontalAlignment.Center
                verticalAlignment: VerticalAlignment.Center
                leftPadding: 40; rightPadding: 40
                layout: StackLayout {}
                Label { horizontalAlignment: HorizontalAlignment.Center; text: "●  MIRROR"; textStyle { color: Color.create("#39d353"); base: SystemDefaults.TextStyles.SmallText; fontWeight: FontWeight.Bold } }
                Label { horizontalAlignment: HorizontalAlignment.Center; text: conn.hostName; topMargin: 6; textStyle { color: Color.White; base: SystemDefaults.TextStyles.BigText; fontWeight: FontWeight.Bold } }
                Label { horizontalAlignment: HorizontalAlignment.Center; topMargin: 6; text: conn.host + "   ·   " + mirror.stateText; textStyle { color: Color.create("#6e7681"); base: SystemDefaults.TextStyles.SmallText } }
                Label {
                    horizontalAlignment: HorizontalAlignment.Center; multiline: true; topMargin: 28
                    text: "Linking to the phone…\nThe live Android screen appears here in a moment."
                    textStyle { color: Color.create("#3d4757"); base: SystemDefaults.TextStyles.SmallText; textAlign: TextAlign.Center }
                }
            }

            // disconnect
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                verticalAlignment: VerticalAlignment.Bottom
                leftPadding: 40; rightPadding: 40; bottomPadding: 32
                layout: DockLayout {}
                TButton { label: "DISCONNECT"; accent: "#f85149"; onClicked: { root.userDisconnected = true; mirror.stop(); root.mirroring = false } }
            }
        }
    }
}
