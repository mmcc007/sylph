[![pub package](https://img.shields.io/pub/v/sylph.svg)](https://pub.dartlang.org/packages/sylph) 
[![Build Status](https://travis-ci.com/mmcc007/sylph.svg?branch=master)](https://travis-ci.com/mmcc007/sylph)

_A sylph is a mythological invisible being of the air._
[Wikipedia](https://en.wikipedia.org/wiki/Sylph)
# Sylph
_Sylph_ is a command line ultility for running Flutter integration and end-to-end tests on pools of real devices in the cloud.

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
All configuration information is passed to Sylph using a configuration file. The default config file is called `sylph.yaml`:
```
project_name: flutter tests
default_job_timeout: 5 # minutes

tmp_dir: /tmp/sylph

device_pools:
    - pool_name: android pool 1
      pool_type: android
      devices:
        - name: Samsung Galaxy S9 (Unlocked)
          model: SM-G960U1
          os: 8.0.0
    - pool_name: ios pool 1
      pool_type: ios
      devices:
        - name: Apple iPhone X
          model: A1865
          os: 12.0

test_suites:
  - test_suite: my tests 1
    app_path: /Users/jenkins/flutter_app
    testspec: test_spec.yaml
    tests:
      - lib/main.dart
    device_pools:
      - android pool 1
#      - ios pool 1
    job_timeout: 5 # minutes
```
# Limitations
Due to mismatch between Flutter and AWS tooling, Sylph currently is limited to working only on pools of android devices on AWS Device Farms.

# Contributing
When contributing to this repository, please feel free to discuss via issue or pull request.

[Issues](https://github.com/mmcc007/screenshots/issues) and [pull requests](https://github.com/mmcc007/screenshots/pulls) are welcome.

Your feedback is used to guide where development effort is focused. So feel free to create as many issues and pull requests as you want. You should expect a timely and considered response.