#!/usr/bin/env bash

set -ex

xcodebuild -version
xcodebuild -project CmdTab.xcodeproj -scheme Release -showBuildSettings | grep SWIFT_VERSION

set -o pipefail && xcodebuild test -project CmdTab.xcodeproj -scheme Test -configuration Release | scripts/xcbeautify
