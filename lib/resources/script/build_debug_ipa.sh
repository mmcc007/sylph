#!/usr/bin/env bash

# constants
default_debug_ipa_name='Debug_Runner.ipa'
default_debug_ipa_dir="."

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
    flutter build ios -t test_driver/main.dart --debug

    echo "Generating debug archive"
    xcodebuild archive \
      -workspace ios/$APP_NAME.xcworkspace \
      -scheme $SCHEME \
      -sdk iphoneos \
      -configuration $CONFIGURATION \
      -archivePath "$ARCHIVE_PATH"

    echo "Generating debug .ipa"
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportOptionsPlist ios/exportOptions.plist \
      -exportPath "$IOS_BUILD_DIR"
    local dst_debug_ipa_path="$default_debug_ipa_dir/$default_debug_ipa_name"
    echo "Moving $APP_NAME.ipa to $dst_debug_ipa_path"
    mv "$IOS_BUILD_DIR/$APP_NAME.ipa" "$dst_debug_ipa_path"
}

build_debug_ipa