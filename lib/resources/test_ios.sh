#!/usr/bin/env bash

set -x

# run integration test on ios
# used on device clouds

show_help() {
    printf "\n\nusage: $0 [--build] [--test package]

Utility for running integration test for pre-installed flutter app on iOS device.
(app must be built in debug mode with 'enableFlutterDriverExtension()')

where:
    --build
        build a debug ipa
        (for install on device in cloud)
    --test
        run default integration test on app
        (for debug ipa installed on device)
    package
        name of package to run, eg, com.example.flutterapp
    --help
        print this message
"
    exit 1
}

build_ipa() {
#    IOS_BUILD_DIR=$PWD/build/ios/Release-iphoneos
    IOS_BUILD_DIR=$PWD/build/ios/Debug-iphoneos
#    cwd=`pwd`
#    flutter build ios -t test_driver/main.dart --debug
#    cd ios
    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Debug archive -archivePath build/ios/Debug-iphoneos/Runner.xcarchive
#    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath build/ios/Release-iphoneos/Runner.xcarchive
    #-arch arm64
#    cd ..
    xcodebuild -exportArchive -archivePath build/ios/Debug-iphoneos/Runner.xcarchive -exportOptionsPlist ios/exportOptions.plist -exportPath build/ios/Debug-iphoneos/Runner.ipa

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
    CONFIGURATION=Release
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

run_test() {
    local package_name=$1

    # note: assumes ipa in debug mode already built and running on device
    # see build_ipa()

    # uninstall/install app
    ideviceinstaller -U $package_name
#    ideviceinstaller -i build/ios/iphoneos/Runner.app

    # use apple python for 'six' package used by ios-deploy
    # (in case there is another python installed)
    export PATH=/usr/bin:$PATH

    ios-deploy --bundle build/ios/iphoneos/Runner.app --no-wifi --justlaunch --args '--enable-dart-profiling --start-paused --enable-checked-mode'

#    idevicesyslog | while read LOGLINE
#    do
#        [[ "${LOGLINE}" == *"Observatory"* ]] && echo $LOGLINE && pkill -P $$ tail
#    done

    # wait for observatory
    obs_str=`( idevicesyslog & ) | grep -m 1 "Observatory listening on"`
    obs_port=`echo $obs_str | grep -Eo '([0-9]+)/$'`
    obs_port=${obs_port%?}
    echo observatory on $obs_port

    # forward port
    forwarded_port=8888
    iproxy $forwarded_port $obs_port
    echo forwarded port on $forwarded_port

    # run test
    flutter packages get
    export VM_SERVICE_URL=http://127.0.0.1:$forwarded_port
    dart test_driver/main_test.dart

}

# if no arguments passed
if [ -z $1 ]; then show_help; fi

case $1 in
    --help)
        show_help
        ;;
    --build)
        build_ipa
        ;;
    --test)
        if [ -z $2 ]; then show_help; fi
        run_test $2
        ;;
esac