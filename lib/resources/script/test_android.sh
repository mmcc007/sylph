#!/usr/bin/env bash
# Originally written by Maurice McCabe <mmcc007@gmail.com>, but placed in the public domain.

# Run Flutter integration tests on android device (or emulator)

# exit on error
set -e
set -x

main() {
  case $1 in
    --help)
        show_help
        ;;
    --run-test)
        if [[ -z $2  || -z $3 ]]; then show_help; fi
        run_test "$2" "$3"
        ;;
    --run-driver)
        if [[ -z $2 ]]; then show_help; fi
        run_no_build $2
        ;;
    *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--help] [--run-test <package name> <test path>] [--run-driver <test main path>

Utility for running integration tests for pre-installed flutter app on android device.
(app must be built in debug mode with 'enableFlutterDriverExtension()')

where:
    --run-test <package name> <test path>
        run test from dart using a custom setup (similar to --no-build)
        <package name>
            name of package to run, eg, com.example.flutterapp
        <test path>
            path of test to run, eg, test_driver/main_test.dart
    --run-driver
        run test using driver --no-build
        <test main path>
            path to test main, eg, test_driver/main.dart
" "$(basename "$0")"
    exit 1
}

run_test() {
    # note: assumes debug apk installed on device
    local package_name=$1
    local test_path=$2

    echo "Starting Flutter app $package_name in debug mode..."

    # stop app on device
    # (if running locally or started incorrectly by CI/CD)
    adb shell am force-stop "$package_name"

    # clear log (to avoid picking up any earlier observatory announcements on local re-runs)
    # (could comment out if running in CI/CD)
    adb logcat -c

    # start app on device
    adb shell am start -a android.intent.action.RUN -f 0x20000000 --ez enable-background-compilation true --ez enable-dart-profiling true --ez enable-checked-mode true "$package_name/$package_name.MainActivity"

    # wait for observatory startup on device and get port number
    obs_str=$(adb logcat -e "Observatory listening on" -m 1)
    obs_port=$(echo "$obs_str" | grep -Eo '([0-9]+)/$')
    obs_port=${obs_port%?}
    echo Observatory on port "$obs_port"

    # forward a local port to observatory port on device
#    forwarded_port=`adb forward tcp:0 tcp:$obs_port`
    forwarded_port=4723 # re-use appium server port for now
    adb forward tcp:"$forwarded_port" tcp:"$obs_port"
    echo Local port "$forwarded_port" forwarded to observatory port "$obs_port"

    # run test
    echo "Running integration test $test_path on app $package_name ..."
#    pub get # may be required when running in CI/CD
    flutter packages get # may be required when running in CI/CD
    export VM_SERVICE_URL=http://127.0.0.1:"$forwarded_port"
    dart "$test_path"
#    flutter driver --use-existing-app=http://127.0.0.1:$forwarded_port --no-keep-app-running lib/main.dart

}

run_no_build() {
  local test_main="$1"

  # disable reporting analytics
  flutter config --no-analytics

  # update .packages in case last build was on a different flutter repo
  flutter packages get

  echo "Running flutter --verbose drive --no-build $1"
  flutter drive --verbose --no-build "$1"
}

main "$@"