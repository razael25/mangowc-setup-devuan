import QtQuick
import Quickshell.Services.Mpris

// Now-playing (MPRIS). Hidden when nothing is playing. Click toggles
// play/pause, scroll skips tracks, right click opens the now-playing
// popup (art, seek, transport, player switcher), middle click dismisses
// the pill until the track (or player) changes — the "I'm watching this
// video, stop telling me about it" gesture. The bar pill stays
// short — truncated title plus a progress underline when the track
// reports a length (streams don't); full track info and exact times
// live in the popup. Among multiple players the playing one wins;
// the popup can pin a choice (dropped if that player exits).
BarModule {
    id: root

    // popup-pinned player; falls back to auto when it disappears
    property var manual: null

    // A player earns the pill by playing, and keeps a claim on it for
    // idleMinutes after it last did anything (play, pause, change track).
    // MPRIS can't tell "paused a moment ago" from "abandoned yesterday"
    // (mpd left paused since before login, a browser keeping a declined
    // call's player), so the bar keeps its own note per player. Playing
    // always wins; among the paused, the most recent one still inside its
    // window — so when a finished call's player times out, the music you
    // paused to take it comes back.
    property int idleMinutes: 5
    property var lastActive: ({})
    property int stamp: 0
    function mark(p) {
        lastActive[p.dbusName] = Date.now()
        stamp++
    }
    Instantiator {
        model: Mpris.players.values
        delegate: Connections {
            required property var modelData
            target: modelData
            Component.onCompleted: {
                if (modelData.playbackState === MprisPlaybackState.Playing)
                    root.mark(modelData)
            }
            function onPlaybackStateChanged() { root.mark(modelData) }
            function onTrackTitleChanged() { root.mark(modelData) }
        }
    }
    // windows close on their own: look again now and then while paused
    Timer {
        running: root.player !== null && !root.playing
        interval: 30000
        repeat: true
        onTriggered: root.stamp++
    }

    readonly property var player: {
        void stamp
        const ps = Mpris.players.values
        if (manual && ps.indexOf(manual) >= 0)
            return manual
        const now = Date.now()
        let playingBest = null, playingAt = -1
        let pausedBest = null, pausedAt = -1
        for (let i = 0; i < ps.length; i++) {
            const p = ps[i]
            const at = lastActive[p.dbusName] ?? -1
            if (at < 0)
                continue
            if (p.playbackState === MprisPlaybackState.Playing) {
                if (at > playingAt) {
                    playingBest = p
                    playingAt = at
                }
            } else if (p.playbackState === MprisPlaybackState.Paused
                       && now - at < idleMinutes * 60000 && at > pausedAt) {
                pausedBest = p
                pausedAt = at
            }
        }
        return playingBest ?? pausedBest
    }
    readonly property bool playing: player !== null
        && player.playbackState === MprisPlaybackState.Playing

    // middle-click; cleared when the track or player changes
    property bool dismissed: false
    onPlayerChanged: dismissed = false

    visible: player !== null && !dismissed
        && player.playbackState !== MprisPlaybackState.Stopped

    // MPRIS reports artists as an array, but some players hand over a
    // plain string — normalize instead of assuming .join exists
    readonly property string artistText: {
        const a = player?.trackArtists
        if (!a) return ""
        return Array.isArray(a) ? a.join(", ") : String(a)
    }

    // MPRIS doesn't push position updates — tick it while playing
    property real pos: 0
    readonly property real len: player?.length ?? 0
    readonly property bool timed: len > 0 && isFinite(len)

    Timer {
        running: root.visible && root.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = root.player?.position ?? 0
    }
    // re-read immediately on track change / seek while paused
    Connections {
        target: root.player
        function onTrackTitleChanged() {
            root.pos = root.player?.position ?? 0
            root.dismissed = false
        }
        function onPositionChanged() { root.pos = root.player?.position ?? 0 }
    }

    function fmt(s) {
        s = Math.max(0, Math.round(s))
        const m = Math.floor(s / 60), r = s % 60
        return (m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0")
                        : m) + ":" + String(r).padStart(2, "0")
    }

    icon: playing ? "󰐊" : "󰏤"
    iconColor: Theme.magenta
    label: {
        if (!player)
            return ""
        const t = artistText !== "" ? artistText + " — " + player.trackTitle
                                    : (player.trackTitle ?? "")
        return t.length > 26 ? t.slice(0, 24) + "…" : t
    }
    progress: timed ? Math.min(pos / len, 1) : -1

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
            popup.visible = !popup.visible
        } else if (mouse.button === Qt.MiddleButton) {
            dismissed = true
            popup.visible = false
        } else if (player && player.canTogglePlaying) {
            player.togglePlaying()
        }
    }
    onScrolled: dir => {
        if (!player)
            return
        if (dir > 0 && player.canGoPrevious)
            player.previous()
        else if (dir < 0 && player.canGoNext)
            player.next()
    }

    MediaPopup {
        id: popup
        anchorItem: root
        media: root
    }
}
