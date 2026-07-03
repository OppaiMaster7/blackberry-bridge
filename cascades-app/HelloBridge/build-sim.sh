#!/usr/bin/env bash
# Full pipeline: build HelloBridge for the BB10 x86 simulator, package, deploy, launch.
# Uses the NDK's bundled JRE 1.7 directly for the java tools (system JDK17 breaks them,
# and cmd.exe ignores forward-slash PATH entries so the .bat wrappers can't be steered).
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

echo "==[1/4] qmake=="
rm -f Makefile HelloBridge HelloBridge.bar main.o
"$BIN/qmake.exe" -spec "$QNX_TARGET/usr/share/qt4/mkspecs/blackberry-x86-qcc" HelloBridge.pro CONFIG+=debug

echo "==[2/4] make=="
"$BIN/make.exe"
file HelloBridge

echo "==[3/4] package=="
"$JAVA" -Djava.awt.headless=true -Xmx512M -cp "$PKG_CP" com.qnx.bbt.nativepackager.BarNativePackager \
    -devMode -package HelloBridge.bar bar-descriptor.xml 2>&1 | grep -viE "^WARNING:"
ls -la HelloBridge.bar

echo "==[4/4] deploy + launch to $DEVICE=="
"$JAVA" -Djava.awt.headless=true -Xmx512M -jar "$L/BarDeploy.jar" \
    -installApp -launchApp -device "$DEVICE" -package HelloBridge.bar 2>&1 | grep -viE "^WARNING:"
echo "PIPELINE_DONE"
