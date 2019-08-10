#!/usr/bin/env bash

main() {
  if ! [[ -d .git ]]; then printError "Error: not in root of repo\n"; show_help; fi

  case $1 in
    --help)
        show_help
        ;;
    --report)
        runReport
        ;;
    *)
        runCodeCoverage
        ;;
  esac
}

show_help() {
    printf "usage: %s [--help] [--report]

Tool for running tests with code coverage.
(run from root of repo)

where:

    --report
        run a coverage report (run code coverage first)
        (requires lcov installed)
    --help
        print this message

requires test_coverage package
(install with 'pub global activate test_coverage')
" "$(basename "$0")"
    exit 1
}

# run tests
runCodeCoverage () {
  test_coverage --no-badge
}

runReport() {
  if [[ -f "coverage/lcov.info" ]]; then
    genhtml -o coverage coverage/lcov.info --no-function-coverage -q
    open coverage/index.html
  else
    printError "Error: coverage has not been run.\n"
    show_help
  fi
}

printError() {
  local msg=$1
  local red
  local none
  # output in red
  red=$(tput setaf 1)
  none=$(tput sgr0)
  printf "%s$msg%s" "${red}" "${none}"
}

main "$@"