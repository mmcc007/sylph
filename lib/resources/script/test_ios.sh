#!/usr/bin/env bash

set -x
set -e

# run integration test on ios
# used on device clouds

main() {
  case $1 in
    --help)
        show_help
        ;;
    --build)
        build_ipa
        ;;
    --test)
        run_test
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--build] [--test package]

Utility for building a debug app as a .ipa, unpacking, and running integration test on an iOS device.
(app must include 'enableFlutterDriverExtension()')

where:
    --build
        build a debug ipa
    --test
        run default integration test on app
    --help
        print this message
" "$(basename "$0")"
    exit 1
}

build_ipa() {
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


#    flutter build ios -t test_driver/main.dart --release

    flutter clean
    flutter build ios -t test_driver/main.dart --debug

    echo "Generating debug archive"
    xcodebuild archive \
      -workspace ios/$APP_NAME.xcworkspace \
      -scheme $SCHEME \
      -sdk iphoneos \
      -configuration $CONFIGURATION \
      -archivePath "$ARCHIVE_PATH"

#    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath build/ios/Release-iphoneos/Runner.xcarchive
    #-arch arm64
#    cd ..

    echo "Generating debug .ipa"
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportOptionsPlist ios/exportOptions.plist \
      -exportPath "$IOS_BUILD_DIR"
    echo "Renaming $APP_NAME.ipa to $FINAL_APP_NAME.ipa"
    mv "$IOS_BUILD_DIR/$APP_NAME.ipa" "$IOS_BUILD_DIR/$FINAL_APP_NAME.ipa"

    # build debug version of app
#    flutter clean
#    flutter drive
#    iphoneDir=build/ios/iphoneos
#    cd build/ios/iphoneos
#    mkdir Payload
#    cp -r Runner.app Payload
#    zip -r Runner.ipa Payload
#    cd ios
#    # start from scratch
#    flutter clean
#    # build release version
#    flutter build ios --release
#    # archive
##    export FLUTTER_BUILD_MODE=Release
#    CONFIGURATION=Release
#    rm -rf $PWD/build/ios/Runner.xcarchive
#    xcodebuild -workspace $PWD/ios/Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration $CONFIGURATION archive -archivePath $IOS_BUILD_DIR/Runner.xcarchive
#    # export as ipa
#    xcodebuild -exportArchive -archivePath $IOS_BUILD_DIR/Runner.xcarchive -exportOptionsPlist $PWD/script/exportOptions.plist -exportPath $IOS_BUILD_DIR/Runner.ipa
#    ideviceinstall -i $IOS_BUILD_DIR/Runner.ipa/Runner.ipa

#    rm -rf $IOS_BUILD_DIR/Payload
#    mkdir $IOS_BUILD_DIR/Payload
#    cp -r $IOS_BUILD_DIR/Runner.app $IOS_BUILD_DIR/Payload
#    zip -r $IOS_BUILD_DIR/Runner.ipa $IOS_BUILD_DIR/Payload
}

# unpack a .app from a .ipa
#ipa_to_app(){
#  local ipa_path=$1
#  local app_path=$2
#
#
#}

run_test() {
    local IOS_BUNDLE="$PWD/build/ios/Debug-iphoneos/Runner.app"
#    local IOS_BUNDLE=$PWD/build/ios/iphoneos/Runner.app


    # note: assumes ipa in debug mode already built and installed on device
    # see build_ipa()

    # uninstall/install app
#    ideviceinstaller -U $package_name
#    ideviceinstaller -i build/ios/iphoneos/Runner.app

    # use apple python for 'six' package used by ios-deploy
    # (in case there is another python installed)
    export PATH=/usr/bin:$PATH

#      --id $DEVICE_ID \
    ios-deploy \
      --bundle "$IOS_BUNDLE" \
      --no-wifi \
      --justlaunch \
      --args '--enable-dart-profiling --start-paused --enable-checked-mode --verify-entry-points'

#    idevicesyslog | while read LOGLINE
#    do
#        [[ "${LOGLINE}" == *"Observatory"* ]] && echo $LOGLINE && pkill -P $$ tail
#    done

    # wait for observatory
    obs_str=$( ( idevicesyslog & ) | grep -m 1 "Observatory listening on")
    obs_port_str=$(echo "$obs_str" | grep -Eo '[0-9a-zA-Z=\/]+\$')
    obs_port=$(echo "$obs_port_str" | grep -Eo '[0-9]+/')
    obs_port=${obs_port%?} # remove last char
    echo observatory on "$obs_port"

    # forward port
#    forwarded_port=1024
    forwarded_port=4723 # re-use appium server port for now
    iproxy "$forwarded_port" "$obs_port"
    echo forwarded port on $forwarded_port

    # run test
    flutter packages get
    export VM_SERVICE_URL=http://127.0.0.1:$forwarded_port
    dart test_driver/main_test.dart

}

main "$@"