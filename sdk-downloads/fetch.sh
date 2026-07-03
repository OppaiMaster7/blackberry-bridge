#!/usr/bin/env bash
# fetch.sh — download the BB10 toolchain from archive.org into this folder.
# Resumable (curl -C -), verifies each file's final byte size against the manifest.
# Re-run safely; completed files are skipped.
set -uo pipefail
cd "$(dirname "$0")"

# url|expected_bytes|output_name
MANIFEST=(
"https://archive.org/download/bbdevtools/momentics-2.1.2-201503050937.win32.x86_64.setup_2.exe|390998264|momentics-2.1.2.win32.x86_64.setup.exe"
"https://archive.org/download/bbdevtools/bbndk.win32.libraries.10.3.1.995.zip|1607600440|bbndk.win32.libraries.10.3.1.995.zip"
"https://archive.org/download/bbdevtools/bbndk.win32.tools.10.3.1.12.zip|304910772|bbndk.win32.tools.10.3.1.12.zip"
"https://archive.org/download/bbdevtools/bbndk.win32.documents.10.3.1.995.zip|32127098|bbndk.win32.documents.10.3.1.995.zip"
"https://archive.org/download/bbdevtools/bbndk.win32.cshost.10.3.1.995.zip|20829727|bbndk.win32.cshost.10.3.1.995.zip"
"https://archive.org/download/bbdevtools/bbndk.win32.samples.10.3.1.995.zip|103804|bbndk.win32.samples.10.3.1.995.zip"
"https://archive.org/download/bbdevtools/bbndk.win32.qconfigmk.10.3.1.995.zip|5492|bbndk.win32.qconfigmk.10.3.1.995.zip"
"https://archive.org/download/blackberry10-device-simulator/BlackBerry10Simulator-Installer-BB10_3_2-281-Win-201503160004.exe|1348610136|BB10-Simulator-10.3.2.281-Win.exe"
)

ok=0; fail=0
for entry in "${MANIFEST[@]}"; do
  IFS='|' read -r url want name <<< "$entry"
  if [[ -f "$name" ]]; then
    have=$(stat -c %s "$name" 2>/dev/null || echo 0)
    if [[ "$have" == "$want" ]]; then echo "SKIP (complete): $name"; ok=$((ok+1)); continue; fi
  fi
  echo ">>> Downloading $name ($want bytes)"
  curl -L -C - --retry 5 --retry-delay 5 --retry-all-errors -o "$name" "$url"
  have=$(stat -c %s "$name" 2>/dev/null || echo 0)
  if [[ "$have" == "$want" ]]; then echo "OK: $name"; ok=$((ok+1));
  else echo "SIZE MISMATCH: $name have=$have want=$want"; fail=$((fail+1)); fi
done

echo "==== DONE: $ok ok, $fail failed ===="
[[ "$fail" == 0 ]] && echo "ALL FILES VERIFIED" || echo "SOME FILES NEED RE-RUN"
