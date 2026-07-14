#!/usr/bin/env bash
set -euo pipefail

readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/tooling/devme-ports.sh"
readonly slot="${DEVME_SLOT:-0}"
readonly convex_port="$(devme_convex_port "$slot")"
readonly derived_data="$root/.devme/DerivedData-$slot"

exec xcodebuild test \
  -project "$root/apps/ios/Starter.xcodeproj" \
  -scheme Starter \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$root/.devme/SourcePackages" \
  -only-testing:StarterTests \
  CODE_SIGNING_ALLOWED=NO \
  CONVEX_URL="http://127.0.0.1:$convex_port"
