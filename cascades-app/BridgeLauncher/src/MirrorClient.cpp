#include "MirrorClient.hpp"

#include <QTcpSocket>
#include <QAbstractSocket>
#include <QtEndian>
#include <bb/cascades/Image>

using namespace bb::cascades;

MirrorClient::MirrorClient(QObject *parent)
    : QObject(parent)
    , m_sock(new QTcpSocket(this))
    , m_active(false)
    , m_streaming(false)
    , m_state("idle")
    , m_expect(0)
    , m_frames(0)
{
    connect(m_sock, SIGNAL(connected()),    this, SLOT(onConnected()));
    connect(m_sock, SIGNAL(readyRead()),    this, SLOT(onReadyRead()));
    connect(m_sock, SIGNAL(disconnected()), this, SLOT(onClosed()));
    connect(m_sock, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(onClosed()));
}

void MirrorClient::setState(const QString &s)
{
    m_state = s;
    emit activeChanged();
}

void MirrorClient::start(const QString &host, int port)
{
    m_sock->abort();
    m_buf.clear();
    m_expect = 0;
    m_frames = 0;
    m_active = true;
    m_streaming = false;
    setState("connecting");
    m_sock->connectToHost(host, port);
}

void MirrorClient::stop()
{
    m_sock->abort();
    m_buf.clear();
    m_expect = 0;
    m_active = false;
    m_streaming = false;
    setState("idle");
}

void MirrorClient::onConnected()
{
    m_streaming = true;
    setState("streaming");
}

void MirrorClient::onClosed()
{
    if (m_active) {
        m_streaming = false;
        setState("link lost");
        m_active = false;
        emit activeChanged();
    }
}

void MirrorClient::onReadyRead()
{
    m_buf.append(m_sock->readAll());
    for (;;) {
        if (m_expect == 0) {
            if (m_buf.size() < 4) break;
            m_expect = qFromLittleEndian<quint32>(reinterpret_cast<const uchar*>(m_buf.constData()));
            m_buf.remove(0, 4);
            if (m_expect == 0 || m_expect > 20000000) { // sanity guard
                m_buf.clear();
                m_expect = 0;
                break;
            }
        }
        if (static_cast<quint32>(m_buf.size()) < m_expect) break;

        QByteArray jpeg = m_buf.left(m_expect);
        m_buf.remove(0, m_expect);
        m_expect = 0;

        m_frame = Image(jpeg);
        ++m_frames;
        emit frameChanged();
    }
}
