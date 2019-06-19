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
        if [[ -z $2 ]]; then show_help; fi
        run_test $2
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--build] [--unpack <path to debug .ipa>] [--dummy-symbols <path to build_to_os map file>] [--test <path to debug app>]

Utility for building a debug app as a .ipa, unpacking, and running integration test on an iOS device.
(app must include 'enableFlutterDriverExtension()')

where:
    --build
        build a debug ipa
    --unpack <path to debug .ipa>
        unpack debug .ipa to build directory for testing
    --dummy-symbols <<path to build_to_os map file>>
        generate dummy symbol directories for ios-deploy
    --test <path to debug app>
        run integration test on debug app
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
  local debug_app_path=$1
  echo "Running flutter drive --no-build $debug_app_path"
  flutter drive --no-build $debug_app_path
}

main "$@"