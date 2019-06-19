#!/usr/bin/env bash

#set -x
set -e

# run integration test on ios
# used on device clouds

# constants
default_debug_ipa_name='Debug_Runner.ipa'
default_debug_ipa_dir="."
debug_app_dir='build/ios/iphoneos'

main() {
  case $1 in
    --help)
        show_help
        ;;
    --build)
        build_debug_ipa
        ;;
    --unpack)
        if [[ -z $2 ]]; then show_help; fi
        unpack_debug_ipa $2
        ;;
    --dummy-symbols)
        if [[ -z $2 ]]; then show_help; fi
        dummy_symbols $2
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
    printf "\n\nusage: %s [--build] [--unpack <path to debug .ipa>] [--dummy-symbols <path to build_to_os map file>] [--test package]

Utility for building a debug app as a .ipa, unpacking, and running integration test on an iOS device.
(app must include 'enableFlutterDriverExtension()')

where:
    --build
        build a debug ipa
    --unpack <path to debug .ipa>
        unpack debug .ipa to build directory for testing
    --dummy-symbols <<path to build_to_os map file>>
        generate dummy symbol directories for ios-deploy
    --test
        run default integration test on app
    --help
        print this message
" "$(basename "$0")"
    exit 1
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

# unpack a debug .app from a .debug ipa
unpack_debug_ipa(){
  local ipa_path=$1
  local unpack_dir='Payload'

  echo "Unpacking $ipa_path to $debug_app_dir..."

  # clear dirs
  rm -rf "$unpack_dir" "$debug_app_dir"
  mkdir -p "$debug_app_dir"

  unzip -q "$ipa_path"
  mv "$unpack_dir/Runner.app" "$debug_app_dir"
  echo "Unpacking of $ipa_path to $debug_app_dir completed successfully."
}

# generate dummy symbol directories for supported iOS devices for ios-deploy
# actual symbols are not used by flutter integration tests
dummy_symbols() {
  local dummy_symbols_path=$1

  typeset -A build
  while IFS=$'=' read key value; do
    build[$key]=$value
  done < $dummy_symbols_path

  for build in "${!build[@]}"
  do
    os=${build[$build]}
    echo "creating $HOME/Library/Developer/Xcode/iOS DeviceSupport/$os ($build)/Symbols"
    mkdir -p "$HOME/Library/Developer/Xcode/iOS DeviceSupport/$os ($build)/Symbols"
  done

}

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