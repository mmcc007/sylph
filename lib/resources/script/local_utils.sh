#!/usr/bin/env bash

# utils run locally

main(){
  case $1 in
    --build-debug-ipa)
        build_debug_ipa
        ;;
    --bundle)
        bundle
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--build-debug-ipa] [--bundle]

Utilities ran locally

where:
    --build-debug-ipa
        package a debug app as a .ipa
        (app must include 'enableFlutterDriverExtension()')
    --bundle
        append to appium bundle for upload to Device Farm
    --help
        print this message
" "$(basename "$0")"
    exit 1
}

# constants
default_debug_ipa_name='Debug_Runner.ipa'
default_debug_ipa_dir="."

bundle() {
  echo not implemented
}

build_debug_ipa() {
    APP_NAME="Runner"
    FINAL_APP_NAME="Debug_Runner"
    SCHEME=$APP_NAME

#    IOS_BUILD_DIR=$PWD/build/ios/Release-iphoneos
    IOS_BUILD_DIR=$PWD/build/ios/Debug-iphoneos
#    CONFIGURATION=Release
    CONFIGURATION=Debug
#    export FLUTTER_BUILD_MODE=Release
    export FLUTTER_BUILD_MODE=Debug
    APP_COMMON_PATH="$IOS_BUILD_DIR/$APP_NAME"
    ARCHIVE_PATH="$APP_COMMON_PATH.xcarchive"

    flutter clean
    flutter packages get # in case building from a different flutter repo
    echo "Running flutter build ios -t test_driver/main.dart --debug..."
    flutter build ios -t test_driver/main.dart --debug

    echo "Generating debug archive..."
    xcodebuild archive \
      -workspace ios/$APP_NAME.xcworkspace \
      -scheme $SCHEME \
      -sdk iphoneos \
      -configuration $CONFIGURATION \
      -archivePath "$ARCHIVE_PATH"

    echo "Generating debug .ipa..."
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportOptionsPlist ios/exportOptions.plist \
      -exportPath "$IOS_BUILD_DIR"
    local dst_debug_ipa_path="$default_debug_ipa_dir/$default_debug_ipa_name"
    echo "Moving $APP_NAME.ipa to $dst_debug_ipa_path"
    mv "$IOS_BUILD_DIR/$APP_NAME.ipa" "$dst_debug_ipa_path"
}

main "$@"