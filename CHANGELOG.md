## 0.7.0+2
- Fixed analyzer warnings and added example readme after publishing

## 0.7.0+1
- Fixed pub.dev warnings after publishing

## 0.7.0
- Fixed bug in gathering job args for concurrent runs #72
- Added support for flavors using 'recommended' example #75 #76
- Added support for bundling external local packages #73 #77

## 0.6.0
- Added verbose mode #56 #66
- Added support for linux and windows #50 #69

## 0.5.0
- Added support for bundling local packages #59
- Added code coverage #53
- Added form factor (phone/tablet) to device listing feature. Sorting by phone then table. #52 #53
- Added tracking error code when running on device farm. #45
- Removed dependency on env vars when not building for iOS. #41

## 0.4.0
- Fixed multiple tests not running on android devices. #31
- Added feature to support configuring a device pool. #35  
Enables looking-up devices from the command line.
- Refactoring. #37
- Added support for configurable iOS build. #30  
Requires adding environment variables.

## 0.3.0
- Removed dependency on forked flutter #13
- Added support for running sylph jobs in parallel #14
- Added support for downloading artifacts per device #15
- Added per job timeouts #17
- Added reporting of test progress per device in pool #19
- Added config validator at start of run #24 #25
- Resolved potential security vulnerability in fastlane #27
- Hid test_spec.yaml from user and allowed multiple tests to run on each device #20 #28

## 0.2.0
- Added support for iOS real devices  
(now supports both iOS and Android real devices)

## 0.1.1

- Downloads artifacts from AWS Device Farm  
(including video and log of running test)

## 0.1.0

- Initial version
