#!/usr/bin/env bash

# utils run locally

set -e
set -x

main(){
  case $1 in
    --build-debug-ipa)
        build_debug_ipa
        ;;
    --ci)
        if [[ -z $2 ]]; then show_help; fi
        config_ci "$2" # dev only
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--build-debug-ipa] [--ci <staging dir>]

Utilities ran locally

where:
    --build-debug-ipa
        package a debug app as a .ipa
        (app must include 'enableFlutterDriverExtension()')
    --ci <staging dir>
        configure a CI build environment // dev only
    --help
        print this message
" "$(basename "$0")"
    exit 1
}

# install certificate and provisioning profile using match
# assumes resources unbundled from sylph
# dev only
config_ci() {
  local app_dir=$1

  # setup ssh for fastlane match
  # set default identity file
#  cat << EOF > ~/.ssh/config
#Host *
#AddKeysToAgent yes
#UseKeychain yes
#IdentityFile $app_dir/dummy-ssh-keys/key
#EOF
#
#  # add MATCH_HOST public key to known hosts
#  ssh-keyscan -t ecdsa -p "$MATCH_PORT" "$MATCH_HOST" >> ~/.ssh/known_hosts
#  chmod 600 "$app_dir/dummy-ssh-keys/key"
#  chmod 700 "$app_dir/dummy-ssh-keys"

  # install fastlane
  gem install bundler:2.0.1 # the fastlane gem file requires bundler 2.0
  (cd "$app_dir/ios"; bundle install)

  # call match to install developer certificate and provisioning profile
  (cd "$app_dir/ios"; fastlane enable_match_code_signing mode:debug)
}

build_debug_ipa() {
    local default_debug_ipa_name='Debug_Runner.ipa'

    APP_NAME="Runner"
    SCHEME=$APP_NAME

#    IOS_BUILD_DIR=$PWD/build/ios/Release-iphoneos
    IOS_BUILD_DIR=$PWD/build/ios/Debug-iphoneos
#    CONFIGURATION=Release
    CONFIGURATION=Debug
#    export FLUTTER_BUILD_MODE=Release
    export FLUTTER_BUILD_MODE=Debug
    APP_COMMON_PATH="$IOS_BUILD_DIR/$APP_NAME"
    ARCHIVE_PATH="$APP_COMMON_PATH.xcarchive"

#    echo "Building debug .ipa for upload to Device Farm..."
#    flutter clean > /dev/null
    flutter packages get > /dev/null # in case building from a different flutter repo
    echo "Running flutter build ios -t test_driver/main.dart --debug..."
    flutter build ios -t test_driver/main.dart --debug

    # cleanup on control-c
    lay_interrupt_signal_traps

    # checkout the xcode backend (just in case)
    recover_archive_disabler

    # remove the debug .ipa disabler
    remove_archive_disabler

    echo "Generating debug archive..."
    xcodebuild archive \
      -workspace ios/$APP_NAME.xcworkspace \
      -scheme $SCHEME \
      -sdk iphoneos \
      -configuration $CONFIGURATION \
      -archivePath "$ARCHIVE_PATH" \
      | xcpretty

     # checkout the xcode backend to recover disabler
     recover_archive_disabler

     # release signal traps
     remove_traps

    echo "Generating debug .ipa at $IOS_BUILD_DIR/$APP_NAME.ipa..."
    xcodebuild -exportArchive \
      -archivePath "$ARCHIVE_PATH" \
      -exportOptionsPlist ios/exportOptions.plist \
      -exportPath "$IOS_BUILD_DIR" \
      | xcpretty

    # rename debug .ipa to standard name
    mv "$IOS_BUILD_DIR/$APP_NAME.ipa" "$IOS_BUILD_DIR/$default_debug_ipa_name"

    echo "Debug .ipa successfully created in $IOS_BUILD_DIR/$default_debug_ipa_name"
}

# temporarily remove debug .ipa archive disabler
remove_archive_disabler() {
  local flutter_path
  flutter_path="$(dirname "$(dirname "$(command -v flutter)")")"
  local xcode_backend_path="$flutter_path/packages/flutter_tools/bin/xcode_backend.sh"

  local original

  # read in script
  original=$(<"$xcode_backend_path")

  # define pattern that matches disabler code to remove
  # shellcheck disable=SC2016
  local pattern='
  if \[\[ \"\$ACTION\" == \"install\" \&\& \"\$build_mode\" != \"release\" \]\]\; then
    EchoError "========================================================================"
    EchoError "ERROR: Flutter archive builds must be run in Release mode."
    EchoError ""
    EchoError "To correct, ensure FLUTTER_BUILD_MODE is set to release or run:"
    EchoError "flutter build ios --release"
    EchoError ""
    EchoError "then re-run Archive from Xcode."
    EchoError "========================================================================"
    exit -1
  fi
'
  # define regular expression
  local re="(.*)$pattern(.*)"
  # xcode_backend.sh with disabler removed
  local removed_disabler

  # search for and remove pattern
  if [[ $original =~ $re ]]; then
    removed_disabler=${BASH_REMATCH[1]}${BASH_REMATCH[2]}
  else
    echo "FATAL ERROR: removal of archive disabler failed. Please create issue in https://github.com/mmcc007/sylph/issues"
    exit 1
  fi

  # write out new script
  echo "$removed_disabler" > "$xcode_backend_path"

  echo "Removed archive disabler in flutter"

}

# recover debug .ipa archive disabler
recover_archive_disabler(){
  local flutter_path
  flutter_path="$(dirname "$(dirname "$(command -v flutter)")")"

  local xcode_backend_path="packages/flutter_tools/bin/xcode_backend.sh"
  (cd "$flutter_path"; git checkout "$xcode_backend_path")
  echo "Recovered archive disabler in flutter"
}

interrupt_signal_handler() {
  echo -en "\n## Sylph caught interrupt signal; Cleaning up and exiting \n"
  recover_archive_disabler
#  exit $?
  exit 1
}

lay_interrupt_signal_traps() {
  # trap interrupt and terminate signals
  trap interrupt_signal_handler SIGINT
  trap interrupt_signal_handler SIGTERM
}

remove_traps() {
  trap - SIGINT
  trap - SIGTERM
}

main "$@"