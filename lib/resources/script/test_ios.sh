#!/usr/bin/env bash

#set -x
set -e

# run integration test on ios
# used on device clouds

main() {
  case $1 in
    --help)
        show_help
        ;;
    --unpack)
        if [[ -z $2 ]]; then show_help; fi
        unpack_debug_ipa "$2"
        ;;
    --dummy-symbols)
        if [[ -z $2 ]]; then show_help; fi
        dummy_symbols "$2"
        ;;
    --run-driver)
        if [[ -z $2 ]]; then show_help; fi
        run_driver "$2" "$3"
        ;;
    --run-tests)
        if [[ -z $2 || -z $3 ]]; then show_help; fi
        run_tests "$2" "$3"
        ;;
   *)
        show_help
        ;;
  esac
}

show_help() {
    printf "\n\nusage: %s [--unpack <path to debug .ipa>] [--dummy-symbols <path to build_to_os map file>] [--run-driver <path to debug app> [<path to test>]] [--run-tests <path to debug app> <comma-delimited list of test paths>]

Utility for building a debug app as a .ipa, unpacking, and running integration tests on an iOS device.
(app must include 'enableFlutterDriverExtension()')

where:
    --unpack <path to debug .ipa>
        unpack debug .ipa to build directory for testing
    --dummy-symbols <path to build_to_os map file>
        generate dummy symbol directories for ios-deploy
    --run-driver <path to debug app> [<path to test>]
        run integration test on debug app with default or specified test
    --run-tests <path to debug app> <comma-delimited list of test paths>
        run integration tests on debug app with list of test paths (eg, 'test_driver/main_test1.dart,test_driver/main_test2.dart')
    --help
        print this message
" "$(basename "$0")"
    exit 1
}

# unpack a debug .app from a .debug ipa
unpack_debug_ipa(){
  local ipa_path=$1
  local unpack_dir='Payload'
  local debug_app_dir='build/ios/iphoneos'


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

  # shellcheck disable=SC2162
  while IFS=$'=' read build os; do
    echo "creating $HOME/Library/Developer/Xcode/iOS DeviceSupport/$os ($build)/Symbols"
    mkdir -p "$HOME/Library/Developer/Xcode/iOS DeviceSupport/$os ($build)/Symbols"
  done < "$dummy_symbols_path"
}

run_tests() {
 local debug_app_path=$1
 while IFS=',' read -ra tests; do
    for test in "${tests[@]}"; do
      run_driver "$debug_app_path" "$test"
    done
  done <<< "$2"
}

run_driver() {
  local debug_app_path=$1
  local test_path=$2

  # disable reporting analytics
  flutter config --no-analytics

  # update .packages in case last build was on a different flutter repo
  flutter packages get

  if [[ -z "$test_path" ]]; then
    echo "Running flutter -v drive --no-build $debug_app_path"
    flutter -v drive --no-build "$debug_app_path"
  else
    echo "Running flutter -v drive --no-build -t $debug_app_path --driver $test_path"
    flutter -v drive --no-build "$debug_app_path" -t "$debug_app_path" --driver "$test_path"
  fi
}

main "$@"