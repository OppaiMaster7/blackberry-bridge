#!/usr/bin/env bash
# Build + package + deploy + launch BridgeLauncher on the BB10 x86 simulator, then pull
# the app log (captures any QML errors main.cpp prints to stderr).
set -e
export QNX_HOST="C:/bbndk/host_10_3_1_12/win32/x86"
export QNX_TARGET="C:/bbndk/target_10_3_1_995/qnx6"
export QNX_CONFIGURATION="C:/Users/user/AppData/Local/Research In Motion/BlackBerry Native SDK"
export PATH="$QNX_HOST/usr/bin:$PATH"
BIN="$QNX_HOST/usr/bin"
JAVA="C:/bbndk/features/com.qnx.tools.jre.win32.x86_64_1.7.0.51/jre/bin/java.exe"
L="$QNX_HOST/usr/lib"
PKG_CP="$L/EccpressoJDK15ECC.jar;$L/EccpressoAll.jar;$L/TrustpointAll.jar;$L/TrustpointJDK15.jar;$L/TrustpointProviders.jar;$L/BarPackager.jar;$L/BarSigner.jar;$L/BarDeploy.jar;$L/BarAir.jar"
DEVICE="${1:-192.168.94.128}"
cd "$(dirname "$0")"

echo "==[1/5] qmake=="
rm -f Makefile BridgeLauncher BridgeLauncher.bar main.o
"$BIN/qmake.exe" -spec "$QNX_TARGET/usr/share/qt4/mkspecs/blackberry-x86-qcc" BridgeLauncher.pro CONFIG+=debug

echo "==[2/5] make=="
"$BIN/make.exe" 2>&1 | grep -viE "^qcc " || true
file BridgeLauncher

echo "==[3/5] package=="
"$JAVA" -Djava.awt.headless=true -Xmx512M -cp "$PKG_CP" com.qnx.bbt.nativepackager.BarNativePackager \
    -devMode -package BridgeLauncher.bar bar-descriptor.xml 2>&1 | grep -viE "^WARNING:" || true
ls -la BridgeLauncher.bar

echo "==[4/5] deploy + launch to $DEVICE=="
# terminate any running instance so the new code actually loads (else launch reports "running")
"$JAVA" -Djava.awt.headless=true -Xmx512M -jar "$L/BarDeploy.jar" \
    -terminateApp -device "$DEVICE" -package BridgeLauncher.bar 2>&1 | grep -iE "result::" || true
"$JAVA" -Djava.awt.headless=true -Xmx512M -jar "$L/BarDeploy.jar" \
    -installApp -launchApp -device "$DEVICE" -package BridgeLauncher.bar 2>&1 | grep -viE "^WARNING:|0B/s|####" || true

echo "==[5/5] pull app log (QML errors, if any)=="
sleep 2
"$JAVA" -Djava.awt.headless=true -Xmx512M -jar "$L/BarDeploy.jar" \
    -getFile logs/log - "$DEVICE" BridgeLauncher.bar 2>&1 | grep -viE "^WARNING:|^Info:" || echo "(no log / app ran clean)"
echo "PIPELINE_DONE"
