#include "VncClient.hpp"

#include <QTcpSocket>
#include <QAbstractSocket>
#include <QTimer>
#include <QImage>
#include <QBuffer>
#include <QIODevice>
#include <bb/cascades/Image>
#include <bb/ImageData>
#include <bb/PixelFormat>
#include <bb/cascades/ImageView>
#include <string.h>
#include <stdio.h>

using namespace bb::cascades;

// handshake phases
enum { P_VERSION = 0, P_SECTYPES, P_SECRESULT, P_SERVERINIT, P_NORMAL };
// framebuffer-update sub-states
enum { M_TYPE = 0, M_FBU_HEAD, M_RECT_HEAD, M_RECT_DATA };

static quint16 be16(const QByteArray &b, int o) {
    return (quint16)((quint8)b[o] << 8 | (quint8)b[o + 1]);
}
static quint32 be32(const QByteArray &b, int o) {
    return ((quint32)(quint8)b[o] << 24) | ((quint32)(quint8)b[o + 1] << 16)
         | ((quint32)(quint8)b[o + 2] << 8) | (quint32)(quint8)b[o + 3];
}

VncClient::VncClient(QObject *parent)
    : QObject(parent)
    , m_sock(new QTcpSocket(this))
    , m_reqTimer(new QTimer(this))
    , m_reconnectTimer(new QTimer(this))
    , m_nudgeTimer(new QTimer(this))
    , m_port(0)
    , m_iv(0), m_suppressReconnect(false), m_userStopped(false)
    , m_active(false), m_streaming(false), m_state("idle"), m_frameCount(0)
    , m_phase(P_VERSION), m_fbw(0), m_fbh(0)
    , m_msgState(M_TYPE), m_rectsLeft(0)
    , m_rx(0), m_ry(0), m_rw(0), m_rh(0), m_renc(0)
{
    connect(m_sock, SIGNAL(connected()),    this, SLOT(onConnected()));
    connect(m_sock, SIGNAL(readyRead()),    this, SLOT(onReadyRead()));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onClosed()));
    connect(m_sock, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(onClosed()));
    m_reqTimer->setSingleShot(true);
    connect(m_reqTimer, SIGNAL(timeout()), this, SLOT(onReqTimer()));
    m_reconnectTimer->setSingleShot(true);
    connect(m_reconnectTimer, SIGNAL(timeout()), this, SLOT(onReconnect()));
    // droidVNC (and some relays) drop clients that stay silent; a periodic incremental
    // request every 2s is harmless traffic that keeps an idle-screen session alive.
    m_nudgeTimer->setInterval(2000);
    connect(m_nudgeTimer, SIGNAL(timeout()), this, SLOT(onNudge()));
}

void VncClient::onReqTimer()
{
    if (m_streaming && m_sock->state() == QAbstractSocket::ConnectedState)
        sendFbUpdateRequest(true);
}

void VncClient::onNudge()
{
    if (m_streaming && m_sock->state() == QAbstractSocket::ConnectedState)
        sendFbUpdateRequest(true);
}

void VncClient::setState(const QString &s) { m_state = s; emit activeChanged(); }

void VncClient::start(const QString &host, int port)
{
    m_suppressReconnect = true;     // the abort below must not trigger a reconnect
    m_reconnectTimer->stop();
    m_sock->abort();
    m_suppressReconnect = false;
    m_userStopped = false;          // an explicit start re-arms auto behavior
    m_host = host;                  // remember for auto-reconnect
    m_port = port;
    m_in.clear();
    m_phase = P_VERSION;
    m_msgState = M_TYPE;
    m_frameCount = 0;
    m_active = true;
    setState("connecting");
    m_sock->connectToHost(host, port);
}

void VncClient::autoStart(const QString &host)
{
    if (m_active || m_userStopped) return;   // don't fight the user or a live session
    start(host, 5900);
}

void VncClient::stop()
{
    m_suppressReconnect = true;     // user asked to stop -> kill reconnect for good
    m_userStopped = true;
    m_host.clear();
    m_active = false;
    m_streaming = false;
    m_reconnectTimer->stop();
    m_nudgeTimer->stop();
    m_sock->abort();
    m_in.clear();
    setState("idle");   // m_streaming=false above -> QML 'visible: mirror.streaming' hides the feed
    m_suppressReconnect = false;
}

void VncClient::fail(const QString &why)
{
    // Mid-stream protocol failure: don't kill the mirror (old behavior bounced the user to
    // the home page) — resync with a quiet reconnect, keeping the last frame on screen.
    fprintf(stderr, "VNC: fail -> reconnect: %s\n", qPrintable(why)); fflush(stderr);
    m_suppressReconnect = true;
    m_sock->abort();
    m_suppressReconnect = false;
    m_in.clear();
    m_nudgeTimer->stop();
    setState("reconnecting");
    if (m_active && !m_host.isEmpty()) m_reconnectTimer->start(1200);
}

void VncClient::onConnected() { fprintf(stderr, "VNC: connected\n"); fflush(stderr); setState("handshaking"); }

void VncClient::onClosed()
{
    if (m_suppressReconnect) return;         // intentional abort (start/stop) -> ignore
    if (!m_active) return;
    // Unexpected drop but we still want the mirror: keep the last frame on screen (no black
    // flash) and quietly retry the same host. Note we do NOT clear m_streaming here.
    m_nudgeTimer->stop();
    setState("reconnecting");
    if (!m_host.isEmpty() && !m_reconnectTimer->isActive()) m_reconnectTimer->start(1200);
}

void VncClient::onReconnect()
{
    if (m_active && !m_host.isEmpty()) start(m_host, m_port);
}

void VncClient::onReadyRead()
{
    m_in.append(m_sock->readAll());
    process();
}

void VncClient::sendSetup()
{
    // SetPixelFormat: type(0) pad(3) + 16-byte pixel format (R,G,B,X big-endian)
    unsigned char spf[20] = {0};
    spf[0] = 0;
    spf[4] = 32;  // bpp
    spf[5] = 24;  // depth
    spf[6] = 1;   // big-endian
    spf[7] = 1;   // true colour
    spf[8] = 0; spf[9] = 255;   // red-max
    spf[10] = 0; spf[11] = 255; // green-max
    spf[12] = 0; spf[13] = 255; // blue-max
    spf[14] = 24; // red-shift
    spf[15] = 16; // green-shift
    spf[16] = 8;  // blue-shift
    m_sock->write(reinterpret_cast<const char*>(spf), 20);

    // SetEncodings: type(2) pad(1) count(2)=1 + RAW(0)
    unsigned char se[8] = {2, 0, 0, 1, 0, 0, 0, 0};
    m_sock->write(reinterpret_cast<const char*>(se), 8);
}

void VncClient::sendFbUpdateRequest(bool incremental)
{
    unsigned char r[10];
    r[0] = 3;
    r[1] = incremental ? 1 : 0;
    r[2] = 0; r[3] = 0;                 // x
    r[4] = 0; r[5] = 0;                 // y
    r[6] = (m_fbw >> 8) & 0xff; r[7] = m_fbw & 0xff;
    r[8] = (m_fbh >> 8) & 0xff; r[9] = m_fbh & 0xff;
    m_sock->write(reinterpret_cast<const char*>(r), 10);
}

void VncClient::sendPointerEvent(int x, int y, int buttonMask)
{
    if (m_sock->state() != QAbstractSocket::ConnectedState) return;
    if (x < 0) x = 0; if (y < 0) y = 0;
    if (m_fbw > 0 && x > m_fbw - 1) x = m_fbw - 1;
    if (m_fbh > 0 && y > m_fbh - 1) y = m_fbh - 1;
    unsigned char p[6];
    p[0] = 5;                              // PointerEvent
    p[1] = (unsigned char)buttonMask;      // bit0 = left button
    p[2] = (x >> 8) & 0xff; p[3] = x & 0xff;
    p[4] = (y >> 8) & 0xff; p[5] = y & 0xff;
    m_sock->write(reinterpret_cast<const char*>(p), 6);
}

void VncClient::pointer(qreal nx, qreal ny, bool pressed)
{
    if (!m_streaming || m_fbw <= 0 || m_fbh <= 0) return;
    if (nx < 0) nx = 0; if (nx > 1) nx = 1;
    if (ny < 0) ny = 0; if (ny > 1) ny = 1;
    // normalized feed coords -> framebuffer pixels (droidVNC scales these back to Android)
    int fx = (int)(nx * (m_fbw - 1) + 0.5);
    int fy = (int)(ny * (m_fbh - 1) + 0.5);
    sendPointerEvent(fx, fy, pressed ? 1 : 0);
    // nudge a fresh frame so the tap's on-screen result shows without waiting for the throttle
    if (m_streaming && !m_reqTimer->isActive()) m_reqTimer->start(30);
}

void VncClient::copyRect(const char *src, int rx, int ry, int rw, int rh)
{
    if (rx < 0 || ry < 0 || rx + rw > m_fbw || ry + rh > m_fbh) return;
    char *dst = m_fb.data();
    for (int y = 0; y < rh; ++y) {
        memcpy(dst + ((ry + y) * m_fbw + rx) * 4, src + (y * rw) * 4, rw * 4);
    }
}

void VncClient::buildImage()
{
    if (m_fbw <= 0 || m_fbh <= 0) return;

    // framebuffer is R,G,B,X (4 bytes/px). Copy straight into a Cascades ImageData as opaque
    // RGBA -> no PNG encode/decode at all, so each frame is cheap AND displays instantly with
    // no black flash (the old flicker came from async PNG decode leaving the view empty).
    bb::ImageData data(bb::PixelFormat::RGBA_Premultiplied, m_fbw, m_fbh);
    const unsigned char *src = reinterpret_cast<const unsigned char*>(m_fb.constData());
    unsigned char *dst = const_cast<unsigned char*>(data.pixels());  // pixels() is const
    const int stride = data.bytesPerLine();
    const int rowBytes = m_fbw * 4;
    for (int y = 0; y < m_fbh; ++y) {
        const unsigned char *s = src + y * rowBytes;
        unsigned char *d = dst + y * stride;
        memcpy(d, s, rowBytes);                        // R,G,B,X straight across
        for (int x = 3; x < rowBytes; x += 4) d[x] = 255;  // force alpha opaque
    }

    m_frame = Image(data);
    if (m_iv) m_iv->setImage(m_frame);   // set directly (QML image binding doesn't refresh)
    ++m_frameCount;
    emit frameChanged();
}

void VncClient::process()
{
    for (;;) {
        if (m_phase == P_VERSION) {
            if (m_in.size() < 12) return;
            m_in.remove(0, 12);
            m_sock->write("RFB 003.008\n", 12);
            m_phase = P_SECTYPES;
        }
        else if (m_phase == P_SECTYPES) {
            if (m_in.size() < 1) return;
            int n = (quint8)m_in.at(0);
            if (n == 0) { fail("server refused"); return; }
            if (m_in.size() < 1 + n) return;
            m_in.remove(0, 1 + n);
            char sel = 1;                       // security: None
            m_sock->write(&sel, 1);
            m_phase = P_SECRESULT;
        }
        else if (m_phase == P_SECRESULT) {
            if (m_in.size() < 4) return;
            quint32 r = be32(m_in, 0);
            m_in.remove(0, 4);
            if (r != 0) { fail("auth failed"); return; }
            char shared = 1;
            m_sock->write(&shared, 1);          // ClientInit
            m_phase = P_SERVERINIT;
        }
        else if (m_phase == P_SERVERINIT) {
            if (m_in.size() < 24) return;
            m_fbw = be16(m_in, 0);
            m_fbh = be16(m_in, 2);
            int namelen = (int)be32(m_in, 20);
            if (m_in.size() < 24 + namelen) return;
            m_in.remove(0, 24 + namelen);
            if (m_fbw <= 0 || m_fbh <= 0 || m_fbw > 4096 || m_fbh > 4096) {
                fail("bad geometry"); return;
            }
            m_fb = QByteArray(m_fbw * m_fbh * 4, 0);
            fprintf(stderr, "VNC: serverinit w=%d h=%d -> streaming\n", m_fbw, m_fbh); fflush(stderr);
            sendSetup();
            sendFbUpdateRequest(false);
            m_streaming = true;
            m_nudgeTimer->start();   // keep idle sessions alive (server drops silent clients)
            setState("streaming");
            m_phase = P_NORMAL;
            m_msgState = M_TYPE;
        }
        else { // P_NORMAL
            if (m_msgState == M_TYPE) {
                if (m_in.size() < 1) return;
                int mt = (quint8)m_in.at(0);
                if (mt == 0) {                       // FramebufferUpdate
                    m_in.remove(0, 1);
                    m_msgState = M_FBU_HEAD;
                } else if (mt == 2) {                // Bell
                    m_in.remove(0, 1);
                } else if (mt == 1) {                // SetColourMapEntries
                    if (m_in.size() < 6) return;
                    int nc = be16(m_in, 4);
                    if (m_in.size() < 6 + nc * 6) return;
                    m_in.remove(0, 6 + nc * 6);
                } else if (mt == 3) {                // ServerCutText
                    if (m_in.size() < 8) return;
                    int len = (int)be32(m_in, 4);
                    if (m_in.size() < 8 + len) return;
                    m_in.remove(0, 8 + len);
                } else {
                    fail("proto error"); return;
                }
            }
            else if (m_msgState == M_FBU_HEAD) {
                if (m_in.size() < 3) return;         // pad(1) + nrects(2)
                m_rectsLeft = be16(m_in, 1);
                m_in.remove(0, 3);
                m_msgState = (m_rectsLeft > 0) ? M_RECT_HEAD : M_TYPE;
                // empty update: re-request via the timer (immediate re-send could busy-loop)
                if (m_rectsLeft == 0 && !m_reqTimer->isActive()) m_reqTimer->start(30);
            }
            else if (m_msgState == M_RECT_HEAD) {
                if (m_in.size() < 12) return;
                m_rx = be16(m_in, 0); m_ry = be16(m_in, 2);
                m_rw = be16(m_in, 4); m_rh = be16(m_in, 6);
                m_renc = (qint32)be32(m_in, 8);
                m_in.remove(0, 12);
                m_msgState = M_RECT_DATA;
            }
            else { // M_RECT_DATA
                if (m_renc != 0) { fail("enc unsupported"); return; } // RAW only
                int need = m_rw * m_rh * 4;
                if (m_in.size() < need) return;
                copyRect(m_in.constData(), m_rx, m_ry, m_rw, m_rh);
                m_in.remove(0, need);
                if (--m_rectsLeft > 0) {
                    m_msgState = M_RECT_HEAD;
                } else {
                    // request the NEXT frame before decoding this one: the network transfer
                    // then overlaps the decode instead of serializing after it. 30ms keeps
                    // the UI thread breathing (the old 70ms was the main lag source).
                    m_reqTimer->start(30);
                    buildImage();
                    m_msgState = M_TYPE;
                }
            }
        }
    }
}
