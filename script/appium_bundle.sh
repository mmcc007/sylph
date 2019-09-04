#!/usr/bin/env bash

# download appium template and pack with requirements to run integration tests
# see https://stackoverflow.com/a/53328272/1420881

set -e

main() {

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
    --bundle-certs) # for dev
        bundle_certs $1
        ;;
    *)
        show_help
        ;;
  esac

}

show_help() {
    printf "\nusage: %s [--download] [--install]

Utility for downloading and installing Appium template.
(for details see https://stackoverflow.com/a/53328272/1420881 )

where:
    --download
        download and save template as asset
    --install
        install template in sylph package
    --bundle
        bundle app, tests, scripts and template into test bundle
        (for manual testing)
    --help
        print this message
" "$(basename "$0")"
    exit 1
}

# appium template bundle source
appium_bundle_template_remote="https://s3-us-west-2.amazonaws.com/aws-devicefarm-support/test_bundle_slim.zip"
appium_bundle_template="assets/appium_bundle_template.zip"

# destination of appium template bundle
sylph_resources_dir='lib/resources'
appium_bundle="$sylph_resources_dir/appium_bundle.zip"

# generate bundle for manual testing
test_bundle="test_bundle"
test_bundle_zip="$test_bundle.zip"
app_dir='example' # todo: pass as parameter
app_dst_dir="$test_bundle/$app_dir"

# app
ios_certs_dir="$app_dst_dir/certs"

# scripts
#android_script="$sylph_resources_dir/test_android.sh"
#ios_script="$sylph_resources_dir/test_ios.sh"
script_dir='script'
script_src_dir="$sylph_resources_dir/$script_dir"
# secure env vars
secure_env_script_dst="$app_dst_dir/$script_dir/secure.env"

# dummy ssh keys for fastlane's match
dummy_ssh_keys_src_dir="$sylph_resources_dir/dummy_ssh_keys"

# fastlane
fastlane_src_dir="$sylph_resources_dir/fastlane"
ios_dst_dir="$app_dst_dir/ios"

# final destination of app-specific files
default_app_dst_dir="$test_bundle/flutter_app"


#runner_ipa=$default_app_dir/ Runner.ipa'

# download asset if not already present
download_bundle_template(){
  if [ -f "$appium_bundle_template" ]; then
    echo "File already exists: $appium_bundle_template"
  else
    echo "Download $appium_bundle_template_remote to $appium_bundle_template"
#    wget $appium_bundle_template_remote --output-file=$appium_bundle_template
    curl $appium_bundle_template_remote -o $appium_bundle_template
  fi
}

# add template as resource in sylph package
install_template(){
  echo "Copy $appium_bundle_template to $appium_bundle"
  cp $appium_bundle_template $appium_bundle
}

# add app to bundle for manual upload and testing
bundle_app(){
  echo "Creating new test bundle"
  echo
  echo "Clear $test_bundle_zip ..."
  rm -f $test_bundle_zip
  rm -rf $test_bundle
  echo "Copy $appium_bundle to $test_bundle_zip ..."
  cp $appium_bundle $test_bundle_zip
  echo "Unzip $test_bundle_zip to $test_bundle ..."
  unzip $test_bundle_zip -d $test_bundle

  # clean build dir in case a build is present
  echo "Clean $app_dir ..."
  cd $app_dir
  flutter clean
  cd - > /dev/null

  echo "Copy $app_dir app ..."
#  mkdir $app_dst_dir
#  cp -r $app_dir/lib $app_dir/pubspec.yaml $app_dir/test_driver $app_dst_dir
  cp -r $app_dir $test_bundle

#  echo "Build testable $app_dir iOS app and copy to $test_bundle ..."
#  cd $app_dir
#  flutter build ios -t test_driver/main.dart --debug
#  cd - > /dev/null
#  mkdir -p $test_bundle/$app_dir/$ios_debug_build_dir
#  cp -r $app_dir/$ios_debug_build_dir/$ios_debug_build $test_bundle/$app_dir/$ios_debug_build_dir

  echo "Copy scripts ..."
#  mkdir -p $app_dst_dir
#  cp -r $android_script $app_dst_dir
#  cp -r $ios_script $app_dst_dir
  cp -r $script_src_dir $app_dst_dir

#  echo "Copy ios debug build into $test_bundle"
#  mkdir -p $default_app_dir/$ios_debug_build_dir
#  cp -r $app_dir/$ios_debug_build_dir/$ios_debug_build $default_app_dir/$ios_debug_build_dir
#  echo "Rename $app_name to $default_app_name"
#  mv $test_bundle/$app_name $test_bundle/$default_app_name

  echo "Remove unused files not used (to reduce zip file size) ..."
  rm -rf $test_bundle/$app_dir/ios/Flutter/Flutter.framework

#  echo "Bundle certs"
#  bundle_certs
  echo "Extract secure env vars and save in file ..."
  extract_secure_env_vars

  echo "Copy dummy ssh keys ..."
  cp -r $dummy_ssh_keys_src_dir $app_dst_dir

  echo "Copy fastlane files ..."
  cp -r $fastlane_src_dir $ios_dst_dir
  cp $sylph_resources_dir/Gemfile* $ios_dst_dir

  echo "Rename $app_dir to $default_app_dst_dir ..."
  mv $test_bundle/$app_dir $default_app_dst_dir

  echo "Zip $test_bundle to $test_bundle_zip ..."
  rm -f $test_bundle_zip
  cd $test_bundle
  zip -r ../$test_bundle_zip .
  cd - > /dev/null

  echo "Ready to manually upload $test_bundle_zip (size $(ls -lah $test_bundle_zip | awk -F " " {'print $5'})"
}

# dev
bundle_certs() {

  local local_key_chain_name='login.keychain'
  local local_key_chain_pass=$1
#  local exported_cert='developer_cert.pem'
  local exported_certs='developer_certs.p12'

  mkdir -p $ios_certs_dir
#  security find-certificate -a -p -c "iPhone Developer" > "$ios_certs_dir/$exported_cert"
  security export -k $local_key_chain_name -P $local_key_chain_pass -t identities -f pkcs12 -o "$ios_certs_dir/$exported_certs"


  local key_chain_name='device_farm_tmp.keychain'
  local key_chain_pass='devicefarm'

  # tmp init for testing
  delete_tmp_keychain

  security create-keychain -p $key_chain_pass $key_chain_name
  security unlock-keychain -p $key_chain_pass $key_chain_name
  security list-keychains -d user -s $key_chain_name # $local_key_chain_name
#  security default-keychain -s buildagent.keychain
  security import "$ios_certs_dir/$exported_certs" -k $key_chain_name -P $local_key_chain_pass -T /usr/bin/codesign
#  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k $key_chain_pass $key_chain_name
  security delete-certificate -c "iPhone Distribution" $key_chain_name

  # export certs from $key_chain_name
  security export -k $key_chain_name -P $local_key_chain_pass -t identities -f pkcs12 -o "$ios_certs_dir/$exported_certs"

  security find-identity -v -p codesigning $key_chain_name

  # tmp init for testing
  delete_tmp_keychain

}

delete_tmp_keychain(){
  # tmp init for testing
  security delete-keychain $key_chain_name
  rm -f ~/Library/Keychains/device_farm_tmp.keychain-db
}

# extract secure env variables and store in file
extract_secure_env_vars(){
  echo "Creating $secure_env_script_dst ..."
#set -o noglob
    cat << EOF >> $secure_env_script_dst
export SSH_SERVER=$SSH_SERVER
export SSH_SERVER_PORT=$SSH_SERVER_PORT
export MATCH_PASSWORD='${MATCH_PASSWORD}'
export PUBLISHING_MATCH_CERTIFICATE_REPO=$PUBLISHING_MATCH_CERTIFICATE_REPO
export FASTLANE_PASSWORD='$FASTLANE_PASSWORD'
export FASTLANE_SESSION='$(printf "%q" "$FASTLANE_SESSION")'
EOF
#set +o noglob
}

main "$@"