[![pub package](https://img.shields.io/pub/v/sylph.svg)](https://pub.dartlang.org/packages/sylph) 
[![Build Status](https://travis-ci.com/mmcc007/sylph.svg?branch=master)](https://travis-ci.com/mmcc007/sylph)

_A sylph is a mythological invisible being of the air._
[Wikipedia](https://en.wikipedia.org/wiki/Sylph)
# _Sylph_
_Sylph_ is a command line utility for running Flutter integration and end-to-end tests on pools of real iOS and Android devices in the cloud. _Sylph_ runs on a developer mac or in a CI environment.

# Installation
```
pub global activate sylph
```

# Usage
```
sylph
```
or, if not using the default config file:
```
sylph -c <path to config file>
```

General usage:
```
usage: sylph [--help] [--config <config file>] [--devices <all|android|ios>]

sample usage: sylph

-c, --config=<sylph.yaml>          Path to config file.
                                   (defaults to "sylph.yaml")

-d, --devices=<all|android|ios>    List availabe devices.
                                   [all, android, ios]

    --help                         Display this help information.
```

# Dependencies
## AWS CLI
Install AWS Command Line Interface (AWS CLI)
```
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
``` 
For alternative install options see:  
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

## AWS CLI Credentials
Configure the AWS CLI credentials:
```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```
For alternative configuration options see:  
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html

# Configuration
All configuration information is passed to _Sylph_ using a configuration file. The default config file is called `sylph.yaml`:
```yaml
# Config file for Flutter tests on real device pools.
# Auto-creates projects and device pools if needed.
# Configures android and ios test runs.
# Builds app, uploads and runs tests.
# Then monitors tests, returns final pass/fail result and downloads artifacts.
# Note: assumes the 'aws' command line utility is logged-in.

# sylph config
tmp_dir: /tmp/sylph
artifacts_dir: /tmp/sylph_artifacts
# local timeout per device farm run
sylph_timeout: 720 # seconds approx
# run on ios and android pools concurrently (for faster results)
concurrent_runs: true

# device farm config
project_name: test concurrent runs
default_job_timeout: 10 # minutes, set at project creation

device_pools:

  - pool_name: android pool 1
    pool_type: android
    devices:
      - name: Google Pixel 2
        model: Google Pixel 2
        os: 8.0.0

  - pool_name: ios pool 1
    pool_type: ios
    devices:
      - name: Apple iPhone X
        model: A1865
        os: 11.4

test_suites:

  - test_suite: example tests 1
    main: test_driver/main.dart
    tests:
      - test_driver/main_test.dart
    pool_names:
      - android pool 1
      - ios pool 1
    job_timeout: 8 # minutes, set per job

```
Multiple test suites, consisting of multiple tests, can be run on each device in each device pool. The 'main' app must include a call to `enableFlutterDriverExtension()`. 

Device pools can consist of multiple devices. Devices in a device pool must be of the same type, iOS or Android.

## Populating a device pool
To add devices to a device pool, pick devices from the list provided by
```
sylph -d android
or
sylph -d ios
```
and add to the appropriate pool type in sylph.yaml. The listed devices are devices currently available on Device Farm.

## Configuration Validation
The sylph.yaml is validated to confirm the devices are  available on Device Farm and tests are present before starting a run.

# Configuring a CI Environment for _Sylph_

## iOS builds
Special handling for building iOS apps is required for running tests on remote real devices. In particular, provisioning profiles and certificates must be installed on the build machine. To install the dependencies needed to complete the iOS build, Fastlane's match is used. _Sylph_ will detect it is running in a CI environment (using the CI environment variable), and will install fastlane files that in turn will install the dependencies needed to build the iOS app using Fastlane's match. The iOS build can then complete as normal.

The following environment variables are required by a CI build to build the iOS app:
- PUBLISHING_MATCH_CERTIFICATE_REPO  
This is the location of the private match repo. It expects an ssh-based url. For example, ssh://git@private.mycompany.com/private_repos/match.git  
- MATCH_PASSWORD  
This is the password that was used to encrypt the git repo's contents during match setup.

For details on how to configure Match see:  
https://docs.fastlane.tools/actions/match/

The following are required by sylph in a CI environment to connect to the match host. The match host is running the ssh server that connects to the git server which serves the match repo. This configuration is required so that PUBLISHING_MATCH_CERTIFICATE_REPO will work via ssh:
- MATCH_HOST  
This is used to configure the CI's ssh client to find the match host. For example, private.mycompany.com.
- MATCH_PORT  
This is used to configure the CI's ssh client to find the match host's ssh port. For example, 22.

## AWS CLI Credentials for CI
The following AWS CLI credentials are required:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

For details on other credentials see:  
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html

Note: the Travis-CI build uses pre-configured AWS CLI values in [.aws/config](.aws/config)
## Example secrets for Travis-CI
_Sylph_ runs on Travis-CI and expects the following environment variables:

![secret variables](art/travis_env_vars.png)
 
# Live demo
To see _Sylph_ in action in a CI environment, a  demo of the [example](example) app is available.  

The log of the live run is here:  
https://travis-ci.com/mmcc007/sylph

The resulting artifacts are here:  
https://github.com/mmcc007/sylph/releases  
(includes a video of test running on device)

# Contributing
When contributing to this repository, please feel free to discuss via issue or pull request.

[Issues](https://github.com/mmcc007/screenshots/issues) and [pull requests](https://github.com/mmcc007/screenshots/pulls) are welcome.

Your feedback is used to guide where development effort is focused. So feel free to create as many issues and pull requests as you want. You should expect a timely and considered response.