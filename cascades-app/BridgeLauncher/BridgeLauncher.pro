APP_NAME = BridgeLauncher

TEMPLATE = app
TARGET   = BridgeLauncher

CONFIG  += qt
QT      += core network declarative

LIBS    += -lbbcascades -lbb -lbbsystem
INCLUDEPATH += $$(QNX_TARGET)/usr/include

HEADERS += src/ConnectionManager.hpp src/VncClient.hpp
SOURCES += src/main.cpp src/ConnectionManager.cpp src/VncClient.cpp

OTHER_FILES += \
    assets/main.qml \
    bar-descriptor.xml
