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

# Configuration
All configuration information is passed to _Sylph_ using a configuration file. The default config file is called `sylph.yaml`:
```yaml
project_name: flutter tests
default_job_timeout: 5 # minutes

tmp_dir: /tmp/sylph
artifacts_dir: /tmp/sylph_artifacts

# local timeout per device farm run
sylph_timeout: 720 # seconds approx
# run on ios and android pools concurrently (for faster results)
concurrent_runs: true

device_pools:

  - pool_name: android pool 1
    pool_type: android
    devices:
      - name: Samsung Galaxy S9 (Unlocked)
        model: SM-G960U1
        os: '8.0.0'

  - pool_name: ios pool 1
    pool_type: ios
    devices:
      - name: Apple iPhone X
        model: A1865
        os: '12.0'

test_suites:

  - test_suite: example tests 1
    main: test_driver/main1.dart
    tests:
      - test_driver/main1_test1.dart
      - test_driver/main1_test2.dart
    device_pools:
      - android pool 1
      - ios pool 1
    job_timeout: 5 # minutes per each device run
    
  - test_suite: example tests 2
    main: test_driver/main2.dart
    tests:
      - test_driver/main2_test1.dart
      - test_driver/main2_test2.dart
    pool_names:
      - android pool 1
      - ios pool 1
    job_timeout: 5 # minutes per each device run
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

# Configuring a CI Environment for _Sylph_

## iOS builds
Special handling for building iOS apps is required for running tests on remote real devices. In particular, provisioning profiles and certificates must be installed on the build machine. To install the dependencies needed to complete the iOS build, Fastlane's match is used. _Sylph_ will detect it is running in a CI environment (using the CI environment variable), and will install fastlane files that in turn will install the dependencies needed to build the iOS app using Fastlane's match. The iOS build can then complete as normal.

The following environment variable is required my Match:


- PUBLISHING_MATCH_CERTIFICATE_REPO  
This is the location of the private match repo. For example, https://matchusername:matchpassword@private.mycompany.com/private_repos/match  
where  
    - matchusername  
    is the username used when setting-up match
    - matchpassword  
    is the password used when setting-up match
    - private.mycompany.com/private_repos/match  
    is the uri path to the match repo (if using git)

For details on how to configure Match see:  
https://docs.fastlane.tools/actions/match/

## AWS CLI Credentials for CI
The following AWS CLI credentials are required:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

For details on other credentials see:  
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html

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