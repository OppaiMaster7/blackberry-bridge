#ifndef MIRRORCLIENT_HPP
#define MIRRORCLIENT_HPP

#include <QObject>
#include <QString>
#include <QByteArray>
#include <bb/cascades/Image>

class QTcpSocket;

// Receives a length-prefixed stream of JPEG frames from the host's mirror server and
// exposes the latest frame as a bb::cascades::Image for a QML ImageView. Exposed as "mirror".
class MirrorClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bb::cascades::Image frame READ frame NOTIFY frameChanged)
    Q_PROPERTY(bool    active    READ active    NOTIFY activeChanged)
    Q_PROPERTY(bool    streaming READ streaming NOTIFY activeChanged)
    Q_PROPERTY(QString stateText READ stateText NOTIFY activeChanged)
    Q_PROPERTY(int     fps       READ fps       NOTIFY frameChanged)

public:
    explicit MirrorClient(QObject *parent = 0);

    bb::cascades::Image frame() const { return m_frame; }
    bool    active()    const { return m_active; }
    bool    streaming() const { return m_streaming; }
    QString stateText() const { return m_state; }
    int     fps()       const { return m_frames; }

    Q_INVOKABLE void start(const QString &host, int port);
    Q_INVOKABLE void stop();

signals:
    void frameChanged();
    void activeChanged();

private slots:
    void onConnected();
    void onReadyRead();
    void onClosed();

private:
    void setState(const QString &s);

    QTcpSocket         *m_sock;
    bb::cascades::Image m_frame;
    bool                m_active;
    bool                m_streaming;
    QString             m_state;
    QByteArray          m_buf;
    quint32             m_expect;
    int                 m_frames;
};

#endif // MIRRORCLIENT_HPP
