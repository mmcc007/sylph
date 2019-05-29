#!/usr/bin/env bash

# download appium template and pack with requirements to run integration tests
# see https://stackoverflow.com/a/53328272/1420881

show_help() {
    printf "\nusage: $0 [--download] [--install]

Utility for downloading and installing Appium template.
(for details see https://stackoverflow.com/a/53328272/1420881 )

where:
    --download
        download and save template as asset
    --install
        install template in sylph package
    --bundle
        bundle app, tests, scripts and template into test bundle
    --help
        print this message
"
    exit 1
}

appium_bundle_template_remote="https://s3-us-west-2.amazonaws.com/aws-devicefarm-support/test_bundle_slim.zip"
appium_bundle_template="assets/appium_bundle_template.zip"
appium_bundle="lib/resources/appium_bundle.zip"
test_bundle="test_bundle.zip"
app_name='example'

# download asset if not already present
download_bundle_template(){
  if [ -f "$appium_bundle_template" ]; then
    echo "File already exists: $appium_bundle_template"
  else
    echo "Downloading $appium_bundle_template_remote to $appium_bundle_template"
#    wget $appium_bundle_template_remote --output-file=$appium_bundle_template
    curl $appium_bundle_template_remote -o $appium_bundle_template
  fi
}

# add template as resource in sylph package
install_template(){
  echo "Copying $appium_bundle_template to $appium_bundle"
  cp $appium_bundle_template $appium_bundle
}

# add app to bundle for manual upload and testing
bundle_app(){
  echo "Copying $appium_bundle to $test_bundle"
  cp $appium_bundle $test_bundle
  echo "Bundling $app_name app and $appium_bundle into $test_bundle"
  zip -r $test_bundle $app_name/lib $app_name/pubspec.yaml $app_name/test_driver
  echo "Bundling scripts into $test_bundle"
  zip -r $test_bundle $app_name/script
}

# if no arguments passed
if [ -z $1 ]; then show_help; fi

case $1 in
    --help)
        show_help
        ;;
    --download)
        download_bundle_template
        ;;
    --install)
        install_template
        ;;
    --bundle)
        bundle_app
        ;;
esac