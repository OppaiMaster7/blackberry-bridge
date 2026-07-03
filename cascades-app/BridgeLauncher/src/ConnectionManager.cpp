#include "ConnectionManager.hpp"

#include <bb/cascades/ArrayDataModel>
#include <QTcpSocket>
#include <QUdpSocket>
#include <QTimer>
#include <QAbstractSocket>
#include <QHostAddress>
#include <QVariantMap>
#include <QStringList>
#include <QSettings>

using namespace bb::cascades;

static const quint16 DISCOVERY_PORT  = 49152;
static const char   *DISCOVERY_MAGIC = "BRIDGE_DISCOVERY_V1";

ConnectionManager::ConnectionManager(ArrayDataModel *hostsModel, QObject *parent)
    : QObject(parent)
    , m_status("offline")
    , m_host("")
    , m_port(0)
    , m_hostName("(no host)")
    , m_scanning(false)
    , m_silentProbe(false)
    , m_sock(new QTcpSocket(this))
    , m_timer(new QTimer(this))
    , m_pollTimer(new QTimer(this))
    , m_udp(new QUdpSocket(this))
    , m_scanTimer(new QTimer(this))
    , m_hosts(hostsModel)
{
    m_timer->setSingleShot(true);
    m_scanTimer->setSingleShot(true);

    connect(m_sock, SIGNAL(connected()), this, SLOT(onConnected()));
    connect(m_sock, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(onFailed()));
    connect(m_timer, SIGNAL(timeout()), this, SLOT(onTimeout()));

    m_udp->bind(QHostAddress(QHostAddress::Any), quint16(0));
    connect(m_udp, SIGNAL(readyRead()), this, SLOT(onUdpReady()));
    connect(m_scanTimer, SIGNAL(timeout()), this, SLOT(onScanDone()));

    // keep the link status live: re-probe the paired host periodically
    m_pollTimer->setInterval(5000);
    connect(m_pollTimer, SIGNAL(timeout()), this, SLOT(onPoll()));
    m_pollTimer->start();
}

void ConnectionManager::setStatus(const QString &s)
{
    if (s != m_status) { m_status = s; emit statusChanged(); }
}

// ---- persistence ----
void ConnectionManager::loadSaved()
{
    QSettings s("BlackBerryBridge", "BridgeLauncher");
    QString ip = s.value("host/ip").toString();
    if (!ip.isEmpty()) {
        m_host = ip;
        m_port = s.value("host/port", 3389).toInt();
        m_hostName = s.value("host/name", ip).toString();
        emit hostChanged();
    }
}

void ConnectionManager::saveHost()
{
    QSettings s("BlackBerryBridge", "BridgeLauncher");
    s.setValue("host/ip", m_host);
    s.setValue("host/port", m_port);
    s.setValue("host/name", m_hostName);
    s.sync();
}

void ConnectionManager::start()
{
    loadSaved();
    if (paired()) refresh();
    scan();
}

// ---- discovery ----
void ConnectionManager::scan()
{
    if (m_hosts) m_hosts->clear();
    m_seen.clear();
    m_scanning = true;
    emit scanningChanged();

    QByteArray probe(DISCOVERY_MAGIC);
    m_udp->writeDatagram(probe, QHostAddress::Broadcast, DISCOVERY_PORT);
    m_udp->writeDatagram(probe, QHostAddress("255.255.255.255"), DISCOVERY_PORT);

    m_scanTimer->start(1800);
}

void ConnectionManager::onUdpReady()
{
    while (m_udp->hasPendingDatagrams()) {
        QByteArray buf;
        buf.resize(m_udp->pendingDatagramSize());
        QHostAddress sender;
        quint16 senderPort = 0;
        m_udp->readDatagram(buf.data(), buf.size(), &sender, &senderPort);

        if (!buf.startsWith("BRIDGE_HOST|"))
            continue;

        QString ip = sender.toString();
        if (ip.startsWith("::ffff:")) ip = ip.mid(7);
        if (m_seen.contains(ip))
            continue;
        m_seen.insert(ip);

        QStringList parts = QString::fromUtf8(buf).split('|');
        QString name = parts.size() > 1 ? parts.at(1) : QString("host");
        int rdpPort  = parts.size() > 3 ? parts.at(3).toInt() : 3389;

        QVariantMap row;
        row["name"] = name;
        row["ip"]   = ip;
        row["port"] = rdpPort;
        if (m_hosts) m_hosts->append(QVariant(row));
    }
}

void ConnectionManager::onScanDone()
{
    m_scanning = false;
    emit scanningChanged();

    // convenience: if nothing is paired yet and exactly one host answered, auto-pair it
    if (!paired() && m_seen.size() == 1 && m_hosts && m_hosts->size() == 1) {
        QVariantMap row = m_hosts->value(0).toMap();
        selectHost(row.value("ip").toString(), row.value("port").toInt(), row.value("name").toString());
    }
}

// ---- pairing ----
void ConnectionManager::selectHost(const QString &ip, int port, const QString &name)
{
    m_host = ip;
    m_port = port;
    m_hostName = name;
    emit hostChanged();
    saveHost();
    refresh();
}

// ---- reachability ----
void ConnectionManager::refresh()
{
    if (m_host.isEmpty()) { setStatus("offline"); return; }
    m_sock->abort();
    // Background polls stay silent: flipping to "connecting" every 5s greyed out the
    // LAUNCH MIRROR button (it binds to status=="connected") half the time.
    if (!m_silentProbe) setStatus("connecting");
    m_timer->start(2500);
    m_sock->connectToHost(m_host, m_port);
}

void ConnectionManager::onPoll()
{
    if (paired() && m_status != "connecting") {
        m_silentProbe = true;
        refresh();
    }
}

void ConnectionManager::onConnected()
{
    m_timer->stop();
    m_sock->abort();
    m_silentProbe = false;
    bool wasOnline = (m_status == "connected");
    setStatus("connected");
    if (!wasOnline) emit linkOnline(m_host);
}

void ConnectionManager::onFailed()
{
    m_timer->stop();
    m_silentProbe = false;
    setStatus("offline");
}

void ConnectionManager::onTimeout()
{
    m_sock->abort();
    m_silentProbe = false;
    setStatus("offline");
}
