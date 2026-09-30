#!/usr/bin/env bash

set -ex

set -o pipefail && xcodebuild -project CmdTab.xcodeproj -scheme Release -derivedDataPath DerivedData | scripts/xcbeautify
file DerivedData/Build/Products/Release/CmdTab.app/Contents/MacOS/CmdTab
