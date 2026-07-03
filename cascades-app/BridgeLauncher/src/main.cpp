// BridgeLauncher — BlackBerry Bridge: discover -> pair -> link -> live mirror.
#include <bb/cascades/Application>
#include <bb/cascades/QmlDocument>
#include <bb/cascades/AbstractPane>
#include <bb/cascades/Page>
#include <bb/cascades/Container>
#include <bb/cascades/Label>
#include <bb/cascades/ArrayDataModel>
#include <bb/cascades/ImageView>
#include <QtDeclarative/QDeclarativeError>
#include <QtCore/QList>
#include <stdio.h>

#include "ConnectionManager.hpp"
#include "VncClient.hpp"

using namespace bb::cascades;

Q_DECL_EXPORT int main(int argc, char **argv)
{
    Application app(argc, argv);

    ArrayDataModel    *hostsModel = new ArrayDataModel(&app);
    ConnectionManager *conn       = new ConnectionManager(hostsModel, &app);
    VncClient         *mirror     = new VncClient(&app);

    QmlDocument *qml = QmlDocument::create("asset:///main.qml");
    qml->setContextProperty("conn", conn);
    qml->setContextProperty("hosts", hostsModel);
    qml->setContextProperty("mirror", mirror);

    AbstractPane *root = 0;
    if (qml->hasErrors()) {
        QList<QDeclarativeError> errs = qml->errors();
        for (int i = 0; i < errs.size(); ++i)
            fprintf(stderr, "QMLERR: %s\n", qPrintable(errs.at(i).toString()));
        fflush(stderr);

        Page *p = new Page();
        Container *c = new Container();
        Label *l = new Label();
        l->setText("QML failed to load - see log");
        c->add(l);
        p->setContent(c);
        root = p;
    } else {
        root = qml->createRootObject<AbstractPane>();
    }

    app.setScene(root);

    // hand the mirror's frame ImageView to the VNC client (direct setImage; the QML
    // image: binding to a changing Image property doesn't refresh in Cascades)
    if (root) {
        bb::cascades::ImageView *feed = root->findChild<bb::cascades::ImageView*>("feed");
        mirror->setImageView(feed);
    }

    // hands-free demo path: the moment the paired host is reachable, launch the mirror
    // (no physical tap needed; DISCONNECT still hands control back to the user)
    QObject::connect(conn, SIGNAL(linkOnline(QString)), mirror, SLOT(autoStart(QString)));

    conn->start();   // discover + pair + live link status

    return Application::exec();
}
