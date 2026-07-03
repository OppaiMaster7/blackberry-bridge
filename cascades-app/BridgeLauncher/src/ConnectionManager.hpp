#ifndef CONNECTIONMANAGER_HPP
#define CONNECTIONMANAGER_HPP

#include <QObject>
#include <QString>
#include <QSet>

namespace bb { namespace cascades { class ArrayDataModel; } }
class QTcpSocket;
class QUdpSocket;
class QTimer;

// Finds Bridge hosts (UDP discovery), pairs with one, keeps a live reachability status
// (TCP), and remembers the paired host across launches. Exposed to QML as "conn".
class ConnectionManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString status   READ status   NOTIFY statusChanged)   // offline|connecting|connected
    Q_PROPERTY(QString host     READ host     NOTIFY hostChanged)
    Q_PROPERTY(int     port     READ port     NOTIFY hostChanged)
    Q_PROPERTY(QString hostName READ hostName NOTIFY hostChanged)
    Q_PROPERTY(bool    paired   READ paired   NOTIFY hostChanged)
    Q_PROPERTY(bool    scanning READ scanning NOTIFY scanningChanged)

public:
    explicit ConnectionManager(bb::cascades::ArrayDataModel *hostsModel, QObject *parent = 0);

    QString status()   const { return m_status; }
    QString host()     const { return m_host; }
    int     port()     const { return m_port; }
    QString hostName() const { return m_hostName; }
    bool    paired()   const { return !m_host.isEmpty(); }
    bool    scanning() const { return m_scanning; }

    Q_INVOKABLE void scan();
    Q_INVOKABLE void selectHost(const QString &ip, int port, const QString &name);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void start();   // called once after QML is wired: load saved host, probe, scan

signals:
    void statusChanged();
    void hostChanged();
    void scanningChanged();
    // emitted on each transition into "connected" — lets the app auto-launch the mirror
    void linkOnline(const QString &host);

private slots:
    void onConnected();
    void onFailed();
    void onTimeout();
    void onUdpReady();
    void onScanDone();
    void onPoll();

private:
    void setStatus(const QString &s);
    void loadSaved();
    void saveHost();

    QString m_status;
    QString m_host;
    int     m_port;
    QString m_hostName;
    bool    m_scanning;
    bool    m_silentProbe;   // background poll: don't flicker status to "connecting"

    QTcpSocket *m_sock;
    QTimer     *m_timer;
    QTimer     *m_pollTimer;

    QUdpSocket *m_udp;
    QTimer     *m_scanTimer;
    bb::cascades::ArrayDataModel *m_hosts;
    QSet<QString> m_seen;
};

#endif // CONNECTIONMANAGER_HPP
