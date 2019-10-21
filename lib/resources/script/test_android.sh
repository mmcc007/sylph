#!/usr/bin/env bash
# Originally written by Maurice McCabe <mmcc007@gmail.com>, but placed in the public domain.

# Run Flutter integration tests on android device (or emulator)

# exit on error
set -e
#set -x

main() {
  case $1 in
    --help)
        show_help
        ;;
    --run-test)
        if [[ -z $2 ]]; then show_help; fi
        custom_test_runner "$2"
        ;;
    --run-tests)
        if [[ -z $2 ]]; then show_help; fi
#        run_tests "$2" "$4" "$6"
        run_tests "$2"
        ;;
    --run-driver)
        if [[ -z $2 ]]; then show_help; fi
        run_no_build "$2"
        ;;
    --get-appid)
        if [[ -z $2 ]]; then show_help; fi
        getAppIdFromApk "$2" #dev
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--help] [--run-test <test path>] [--run-driver <test main path>] [--run-tests <comma-delimited list of test paths>]

Utility for running integration tests for pre-installed flutter app on android device.
(app must be built in debug mode with 'enableFlutterDriverExtension()')

where:
    --run-test <test path>
        run test from dart using a custom setup (similar to --no-build)
        <test path>
            path of test to run, eg, test_driver/main_test.dart
    --run-tests <array of test paths>
        run tests from dart using a custom setup (similar to --no-build)
        <comma-delimited list of test paths>
            list of test paths (eg, 'test_driver/main_test1.dart,test_driver/main_test2.dart')
    --run-driver
        run test using driver --no-build
        <test main path>
            path to test main, eg, test_driver/main.dart
" "$(basename "$0")"
    exit 1
}

run_tests() {
  local test_paths=$1 # comma-delimited list of test paths

  while IFS=',' read -ra tests; do # parse comma-delimited list into real list of [tests]
    for test in "${tests[@]}"; do
#        custom_test_runner "$test" "$2" "$3"
        custom_test_runner "$test"
    done
  done <<< "$test_paths"
}

# note: assumes debug apk installed on device
# note: by-passes flutter drives dependency on Android SDK which requires installing the SDK
#       (see https://github.com/flutter/flutter/issues/34909)
custom_test_runner() {
    local test_path=$1
    local forwarded_port=4723 # re-use appium server port if on device farm host

    local app_id
    app_id=$(grep applicationId android/app/build.gradle | awk '{print $2}' | tr -d '"')
#    local package
#    package=app_id

#    if [ -z "$2" ]
#      then
#        echo "null package name"
#      else
#        echo "package name: $2"
#        package=$2
#    fi
#
#    if [ -z "$3" ]
#      then
#        echo "null app id"
#      else
#        app_id=$3
#    fi

    echo "Starting Flutter app $app_id in debug mode..."

    flutter packages get # may be required when running in CI/CD

    adb version

    # stop app on device
    # (if already running locally or started incorrectly by CI/CD)
    adb shell am force-stop "$app_id"

    # clear log (to avoid picking up any earlier observatory announcements on re-runs)
    adb logcat -c

    # start app on device
    adb shell am start -a android.intent.action.RUN -f 0x20000000 --ez enable-background-compilation true --ez enable-dart-profiling true --ez enable-checked-mode true --ez verify-entry-points true --ez start-paused true "$app_id/.MainActivity"

    # wait for observatory startup on device and get port number
    obs_str=$( (adb logcat -v time &) | grep -m 1 "Observatory listening on")
    obs_port_str=$(echo "$obs_str" | grep -Eo '[^:]*$')
    obs_port=$(echo "$obs_port_str" | grep -Eo '^[0-9]+')
    obs_token=$(echo "$obs_port_str" | grep -Eo '\/.*\/$')
    echo Observatory on port "$obs_port"

    # since only one local port seems to work on device farm, confirm that port has been released
    # before re-using. This is so that multiple tests can be run on same device
    port_forwarded=$(adb forward --list| grep ${forwarded_port}) || true
    if [[ ! "$port_forwarded" == "" ]]; then
      echo "unforwarding ${forwarded_port}"
      adb forward --remove tcp:${forwarded_port}
    fi

    # forward a local port to observatory port on device
    if [[ ! "$USERNAME" == 'device-farm' ]]; then
      forwarded_port=$(adb forward tcp:0 tcp:"$obs_port")
    else
      adb forward tcp:"$forwarded_port" tcp:"$obs_port" # if running locally
    fi
    echo Local port "$forwarded_port" forwarded to observatory port "$obs_port"

    # run test
    echo "Running integration test $test_path on app $app_id ..."
    export VM_SERVICE_URL=http://127.0.0.1:"$forwarded_port$obs_token"
    dart "$test_path"
}

# get app id from .apk
# (assumes a built .apk is available locally)
# dev
getAppIdFromApk() {
  local apk_path="$1"

  # regular expression (required)
  # shellcheck disable=SC2089
  local re="L.*/MainActivity.*;"
  # sed substitute expression
  # shellcheck disable=SC2089
  local se="s:L\(.*\)/MainActivity;:\1:p"
  # tr expression
  local te=" / .";

  local app_id
  # shellcheck disable=SC2089
  app_id="$(unzip -p "$apk_path" classes.dex | strings | grep -Eo "$re" | sed -n -e "$se" | tr $te)"

  echo "$app_id"
}

# note: requires android sdk be installed to get app identifier (eg, com.example.example)
# not currently used
#       (see https://github.com/flutter/flutter/issues/34909)
run_no_build() {
  local test_main="$1"

  # disable reporting analytics
  flutter config --no-analytics

  # update .packages in case last build was on a different flutter repo
  flutter packages get

  echo "Running flutter --verbose drive --no-build $test_main"
  flutter drive --verbose --no-build "$test_main"
}

main "$@"