// HelloBridge — minimal Cascades app, UI built in pure C++ (no QML asset to fail to load).
// Proves build -> deploy -> run on the BB10 simulator. No Q_OBJECT, so no moc needed.
#include <bb/cascades/Application>
#include <bb/cascades/Page>
#include <bb/cascades/Container>
#include <bb/cascades/Label>
#include <bb/cascades/Color>
#include <bb/cascades/DockLayout>
#include <bb/cascades/StackLayout>

using namespace bb::cascades;

Q_DECL_EXPORT int main(int argc, char **argv)
{
    Application app(argc, argv);

    Container *root = new Container();
    root->setLayout(new DockLayout());
    // light background + default (dark) label text => guaranteed visible
    root->setBackground(Color::fromARGB(0xfff5f3e7));

    Container *col = new Container();
    col->setLayout(new StackLayout());
    col->setHorizontalAlignment(HorizontalAlignment::Center);
    col->setVerticalAlignment(VerticalAlignment::Center);

    Label *title = new Label();
    title->setText("BlackBerry Bridge");
    title->setHorizontalAlignment(HorizontalAlignment::Center);

    Label *sub = new Label();
    sub->setText("build -> deploy -> run: ALIVE");
    sub->setHorizontalAlignment(HorizontalAlignment::Center);

    Label *note = new Label();
    note->setText("720 x 720 terminal");
    note->setHorizontalAlignment(HorizontalAlignment::Center);

    col->add(title);
    col->add(sub);
    col->add(note);
    root->add(col);

    Page *page = new Page();
    page->setContent(root);

    app.setScene(page);
    return Application::exec();
}
