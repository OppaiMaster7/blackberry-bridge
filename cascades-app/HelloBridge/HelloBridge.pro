APP_NAME = HelloBridge

TEMPLATE = app
TARGET   = HelloBridge

CONFIG  += qt
QT      += core

# Cascades + supporting BB10 libs
LIBS    += -lbbcascades -lbb -lbbsystem

# Sysroot include (cascades headers live under $QNX_TARGET/usr/include/bb/cascades)
INCLUDEPATH += $$(QNX_TARGET)/usr/include

SOURCES += src/main.cpp

OTHER_FILES += \
    assets/main.qml \
    bar-descriptor.xml
