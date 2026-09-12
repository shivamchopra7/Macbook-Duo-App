#!/bin/bash
# Builds the Mac App Store package for Macbook Duo, which the store sells as
# "Lid Fold" (App Review Guideline 5.2.5 keeps Apple's product names out of
# App Store app names). The Xcode project and scheme keep the Macbook Duo name;
# only the product, its bundle and the package are called Lid Fold.
#
#   scripts/appstore.sh [validate|export|upload]
#
#   export    (default) archive the "Macbook Duo" scheme and export a signed
#             "Lid Fold.pkg" into build-appstore/export
#   validate  export, then run App Store validation on the package
#   upload    export, then upload the package to App Store Connect
#
# validate and upload use `xcrun altool` when ASC_KEY_ID and ASC_ISSUER_ID are
# set (an App Store Connect API key must be installed under
# ~/.appstoreconnect/private_keys or ~/private_keys). Without them the script
# prints the manual Transporter.app steps instead.
#
# Provisioning: set MACBOOKDUO_PROVISIONING_UPDATES=1 the first time on a new
# Mac so Xcode can register the App ID and download the App Store profile.
# It is off by default because Xcode's automatic "repair" has been seen
# rewriting App/MacbookDuo.entitlements and dropping the device.usb entitlement
# the lid sensor needs; the guards below fail the build if that ever happens.
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:-export}"
PROJECT="Macbook Duo.xcodeproj"
SCHEME="Macbook Duo"
BUILD_DIR="build-appstore"
ARCHIVE="$BUILD_DIR/LidFold.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
STORE_NAME="Lid Fold"
PACKAGE="$EXPORT_DIR/$STORE_NAME.pkg"
EXPORT_OPTIONS="App/ExportOptions.plist"
ENTITLEMENTS_FILE="App/MacbookDuo.entitlements"
REQUIRED_ENTITLEMENTS=(com.apple.security.app-sandbox com.apple.security.device.usb)
PROVISIONING_FLAG=()
[[ "${MACBOOKDUO_PROVISIONING_UPDATES:-0}" == "1" ]] && PROVISIONING_FLAG=(-allowProvisioningUpdates)

usage() {
  printf 'Usage: %s [validate|export|upload]\n' "$0" >&2
  exit 2
}

case "$ACTION" in
  validate|export|upload) ;;
  *) usage ;;
esac

generate_project() {
  if [[ ! -d "$PROJECT" || "project.yml" -nt "$PROJECT/project.pbxproj" ]]; then
    echo "==> Generating $PROJECT from project.yml"
    xcodegen generate
  else
    echo "==> $PROJECT is up to date with project.yml"
  fi
}

# Every required entitlement must be in the given signed app, and the source
# entitlements file must be exactly what is committed.
check_entitlements() {
  local app="$1" label="$2" key
  local signed; signed="$(codesign -d --entitlements - "$app" 2>/dev/null || true)"
  for key in "${REQUIRED_ENTITLEMENTS[@]}"; do
    if ! grep -q "$key" <<<"$signed"; then
      echo "ERROR: $label is missing the $key entitlement; the lid sensor would not work. Not continuing." >&2
      exit 1
    fi
  done
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && ! git diff --quiet -- "$ENTITLEMENTS_FILE"; then
    echo "ERROR: $ENTITLEMENTS_FILE was modified during the build (Xcode's automatic signing repair). Restore it with: git checkout -- $ENTITLEMENTS_FILE" >&2
    exit 1
  fi
  echo "==> $label carries: ${REQUIRED_ENTITLEMENTS[*]}"
}

# The store build must present itself as Lid Fold: bundle name, display name
# and the bundle folder itself, while keeping the registered bundle identifier.
check_store_name() {
  local app="$1" label="$2" plist="$1/Contents/Info.plist" key value
  for key in CFBundleName CFBundleDisplayName; do
    value="$(/usr/libexec/PlistBuddy -c "Print $key" "$plist" 2>/dev/null || true)"
    if [[ "$value" != "$STORE_NAME" ]]; then
      echo "ERROR: $label has $key '$value', expected '$STORE_NAME'. Not continuing." >&2
      exit 1
    fi
  done
  value="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$plist" 2>/dev/null || true)"
  if [[ "$value" != "com.shivamchopra.macbookduo" ]]; then
    echo "ERROR: $label has bundle identifier '$value', expected com.shivamchopra.macbookduo. Not continuing." >&2
    exit 1
  fi
  echo "==> $label is named $STORE_NAME ($value)"
}

archive_app() {
  echo "==> Archiving $SCHEME (Release) to $ARCHIVE"
  rm -rf "$ARCHIVE"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination "generic/platform=macOS" -archivePath "$ARCHIVE" \
    archive ${PROVISIONING_FLAG[@]+"${PROVISIONING_FLAG[@]}"}
  check_entitlements "$ARCHIVE/Products/Applications/$STORE_NAME.app" "Archived app"
  check_store_name "$ARCHIVE/Products/Applications/$STORE_NAME.app" "Archived app"
}

export_package() {
  echo "==> Exporting App Store package to $EXPORT_DIR"
  rm -rf "$EXPORT_DIR"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTIONS" -exportPath "$EXPORT_DIR" \
    ${PROVISIONING_FLAG[@]+"${PROVISIONING_FLAG[@]}"}
  if [[ ! -f "$PACKAGE" ]]; then
    echo "Export finished but $PACKAGE was not produced. Contents of $EXPORT_DIR:" >&2
    ls -la "$EXPORT_DIR" >&2
    exit 1
  fi
  local scratch; scratch="$(mktemp -d)"
  pkgutil --expand-full "$PACKAGE" "$scratch/pkg" >/dev/null
  local packaged_app; packaged_app="$(find "$scratch/pkg" -name "$STORE_NAME.app" | head -1)"
  if [[ -z "$packaged_app" ]]; then
    echo "ERROR: $PACKAGE does not contain $STORE_NAME.app. Not continuing." >&2
    exit 1
  fi
  check_entitlements "$packaged_app" "Exported package app"
  check_store_name "$packaged_app" "Exported package app"
  rm -rf "$scratch"
  echo "==> Package ready: $PACKAGE"
}

have_api_key() {
  [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]
}

print_transporter_steps() {
  cat <<EOF
ASC_KEY_ID and ASC_ISSUER_ID are not set, so altool was not run. To $1 manually:
  1. Open Transporter.app (free on the Mac App Store) and sign in with the
     Apple ID that belongs to team ZB6623U832.
  2. Drag "$PACKAGE" into the window.
  3. Click Verify to validate, then Deliver to upload.
Alternatively export an App Store Connect API key (App Store Connect >
Users and Access > Integrations), place the .p8 file in
~/.appstoreconnect/private_keys, and rerun with:
  ASC_KEY_ID=<key id> ASC_ISSUER_ID=<issuer id> scripts/appstore.sh $1
EOF
}

validate_package() {
  if have_api_key; then
    echo "==> Validating $PACKAGE with altool"
    xcrun altool --validate-app -f "$PACKAGE" -t macos \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  else
    print_transporter_steps validate
  fi
}

upload_package() {
  if have_api_key; then
    echo "==> Uploading $PACKAGE with altool"
    xcrun altool --upload-app -f "$PACKAGE" -t macos \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  else
    print_transporter_steps upload
  fi
}

print_next_steps() {
  cat <<EOF

Next steps:
  1. Create the app record in App Store Connect (https://appstoreconnect.apple.com)
     with bundle ID com.shivamchopra.macbookduo, name "$STORE_NAME",
     category Utilities, version 1.0.0 (the build number is CURRENT_PROJECT_VERSION in project.yml).
  2. If you have not uploaded yet: scripts/appstore.sh upload, or use
     Transporter.app with "$PACKAGE".
  3. In App Store Connect, wait for the build to finish processing, then attach
     it to the 1.0.0 version.
  4. Fill in the listing: description, keywords, screenshots (1280x800,
     1440x900, 2560x1600 or 2880x1800), support URL
     https://github.com/shivamchopra7/Macbook-Duo-App/issues and privacy policy
     URL https://macbookduo.illusionart.ai/privacy.html.
  5. Complete App Privacy (no data collected) and the export compliance
     question (no non-exempt encryption; ITSAppUsesNonExemptEncryption is
     already false in Info.plist).
  6. Add review notes explaining that the app reads the lid-angle sensor via
     the com.apple.security.device.usb entitlement and needs Screen Recording
     permission, then submit for review.
EOF
}

generate_project
archive_app
export_package
case "$ACTION" in
  validate) validate_package ;;
  upload) upload_package ;;
esac
print_next_steps
