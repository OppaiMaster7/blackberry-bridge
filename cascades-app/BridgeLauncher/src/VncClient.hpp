#ifndef VNCCLIENT_HPP
#define VNCCLIENT_HPP

#include <QObject>
#include <QString>
#include <QByteArray>
#include <bb/cascades/Image>

class QTcpSocket;
class QTimer;
namespace bb { namespace cascades { class ImageView; } }

// Minimal VNC (RFB 3.8) client: security 'None', RAW encoding, pixel format R,G,B,X.
// Decodes the host's framebuffer into a bb::cascades::Image for a QML ImageView.
// Exposed to QML as "mirror" (same property names the mirror screen already binds to).
class VncClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bb::cascades::Image frame READ frame NOTIFY frameChanged)
    Q_PROPERTY(bool    active    READ active    NOTIFY activeChanged)
    Q_PROPERTY(bool    streaming READ streaming NOTIFY activeChanged)
    Q_PROPERTY(QString stateText READ stateText NOTIFY activeChanged)
    Q_PROPERTY(int     frames    READ frames    NOTIFY frameChanged)

public:
    explicit VncClient(QObject *parent = 0);

    bb::cascades::Image frame() const { return m_frame; }
    bool    active()    const { return m_active; }
    bool    streaming() const { return m_streaming; }
    QString stateText() const { return m_state; }
    int     frames()    const { return m_frameCount; }

    Q_INVOKABLE void start(const QString &host, int port);
    Q_INVOKABLE void stop();
    // Touch passthrough from QML. nx,ny are normalized (0..1) within the feed ImageView;
    // pressed = finger down/moving (button 1) vs up. Sent to the host as a VNC PointerEvent,
    // which droidVNC-NG injects into Android via its accessibility InputService.
    Q_INVOKABLE void pointer(qreal nx, qreal ny, bool pressed);
    void setImageView(bb::cascades::ImageView *iv) { m_iv = iv; }

public slots:
    // wired to ConnectionManager::linkOnline — launches the mirror hands-free unless the
    // user is already mirroring or explicitly disconnected this session
    void autoStart(const QString &host);

signals:
    void frameChanged();
    void activeChanged();

private slots:
    void onConnected();
    void onReadyRead();
    void onClosed();
    void onReqTimer();
    void onReconnect();
    void onNudge();

private:
    void setState(const QString &s);
    void fail(const QString &why);   // protocol/stream failure -> quiet reconnect, not stop
    void process();
    void buildImage();
    void copyRect(const char *src, int rx, int ry, int rw, int rh);
    void sendSetup();
    void sendFbUpdateRequest(bool incremental);
    void sendPointerEvent(int x, int y, int buttonMask);

    QTcpSocket             *m_sock;
    QTimer                 *m_reqTimer;
    QTimer                 *m_reconnectTimer;
    QTimer                 *m_nudgeTimer;   // periodic update request: keeps idle links alive
    QString                 m_host;   // remembered for auto-reconnect
    int                     m_port;
    bb::cascades::ImageView *m_iv;
    bool                     m_suppressReconnect; // guard around intentional aborts
    bool                     m_userStopped;       // user hit DISCONNECT -> no auto-start
    bb::cascades::Image      m_frame;
    bool                 m_active;
    bool                 m_streaming;
    QString              m_state;
    int                  m_frameCount;

    QByteArray m_in;        // receive buffer
    int        m_phase;     // handshake phase
    int        m_fbw, m_fbh;
    QByteArray m_fb;        // RGBX framebuffer

    // framebuffer-update sub-state
    int m_msgState;
    int m_rectsLeft;
    int m_rx, m_ry, m_rw, m_rh, m_renc;
};

#endif // VNCCLIENT_HPP
