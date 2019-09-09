import 'bundle_test.dart' as bundle_test;
import 'base/concurrent_jobs_test.dart' as concurrent_jobs_test;
import 'config_test.dart' as config_test;
import 'device_farm_test.dart' as device_farm_test;
import 'base/devices_test.dart' as devices_test;
import 'base/local_packages_test.dart' as local_packages_test;
import 'resources_test.dart' as resources_test;
import 'sylph_run_test.dart' as sylph_run_test;
import 'base/utils_test.dart' as utils_test;
import 'validator_test.dart' as validator_test;

main() {
  bundle_test.main();
  concurrent_jobs_test.main();
  config_test.main();
  device_farm_test.main();
  devices_test.main();
  local_packages_test.main();
  resources_test.main();
  sylph_run_test.main();
  utils_test.main();
  validator_test.main();
}
