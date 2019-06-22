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
        custom_run_test "$2"
        ;;
    --run-driver)
        if [[ -z $2 ]]; then show_help; fi
        run_no_build "$2"
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--help] [--run-test <test path>] [--run-driver <test main path>

Utility for running integration tests for pre-installed flutter app on android device.
(app must be built in debug mode with 'enableFlutterDriverExtension()')

where:
    --run-test <test path>
        run test from dart using a custom setup (similar to --no-build)
        <test path>
            path of test to run, eg, test_driver/main_test.dart
    --run-driver
        run test using driver --no-build
        <test main path>
            path to test main, eg, test_driver/main.dart
" "$(basename "$0")"
    exit 1
}

# note: assumes debug apk installed on device
custom_run_test() {
    local test_path=$1

    local app_id
    app_id=$(grep applicationId android/app/build.gradle | awk '{print $2}' | tr -d '"')

    echo "Starting Flutter app $app_id in debug mode..."

    adb version
    adb start-server

    # stop app on device
    # (if already running locally or started incorrectly by CI/CD)
    adb shell am force-stop "$app_id"

    # clear log (to avoid picking up any earlier observatory announcements on local re-runs)
    [[ ! $USERNAME == 'device-farm' ]] && adb logcat -c

    # start app on device
    adb shell am start -a android.intent.action.RUN -f 0x20000000 --ez enable-background-compilation true --ez enable-dart-profiling true --ez enable-checked-mode true --ez verify-entry-points true --ez start-paused true "$app_id/$app_id.MainActivity"

    # wait for observatory startup on device and get port number
    obs_str=$( (adb logcat -v time &) | grep -m 1 "Observatory listening on")
    obs_port_str=$(echo "$obs_str" | grep -Eo '[^:]*$')
    obs_port=$(echo "$obs_port_str" | grep -Eo '^[0-9]+')
    obs_token=$(echo "$obs_port_str" | grep -Eo '\/.*\/$')
    echo Observatory on port "$obs_port"

    # forward a local port to observatory port on device
    forwarded_port=4723 # re-use appium server port for now
    if [[ ! "$USERNAME" == 'device-farm' ]]; then
      forwarded_port=$(adb forward tcp:0 tcp:"$obs_port")
    else
      adb forward tcp:"$forwarded_port" tcp:"$obs_port"
    fi
    echo Local port "$forwarded_port" forwarded to observatory port "$obs_port"

    # run test
    echo "Running integration test $test_path on app $app_id ..."
    flutter packages get # may be required when running in CI/CD
    flutter packages get # may be required when running in CI/CD
    export VM_SERVICE_URL=http://127.0.0.1:"$forwarded_port$obs_token"
    dart "$test_path"
}

# note: requires android sdk be installed to get app identifier (eg, com.example.example)
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