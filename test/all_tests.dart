import 'bundle_test.dart' as bundle_test;
import 'commands/config_test.dart' as command_config_test;
import 'commands/devices_test.dart' as command_devices_test;
import 'commands/run_test.dart' as command_run_test;
import 'base/concurrent_jobs_test.dart' as concurrent_jobs_test;
import 'config_test.dart' as config_test;
import 'base/crash_reporting_test.dart' as crash_report_test;
import 'device_farm_test.dart' as device_farm_test;
import 'base/devices_test.dart' as devices_test;
import 'base/local_packages_test.dart' as local_packages_test;
import 'resources_test.dart' as resources_test;
import 'base/runner/runner_test.dart' as runner_test;
import 'base/runner/sylph_command_runner_test.dart' as sylph_command_runner_test;
import 'base/runner/sylph_command_test.dart' as sylph_command_test;
import 'sylph_run_test.dart' as sylph_run_test;
import 'base/utils_test.dart' as utils_test;
import 'validator_test.dart' as validator_test;

main() {
  bundle_test.main();
  command_config_test.main();
  command_devices_test.main();
  command_run_test.main();
  concurrent_jobs_test.main();
  config_test.main();
  crash_report_test.main();
  device_farm_test.main();
  devices_test.main();
  local_packages_test.main();
  resources_test.main();
//  run_test.main();
  runner_test.main();
  sylph_command_runner_test.main();
  sylph_command_test.main();
  sylph_run_test.main();
  utils_test.main();
  validator_test.main();
}
