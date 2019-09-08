import 'bundle_test.dart' as bundle_test;
import 'concurrent_jobs_test.dart' as concurrent_jobs_test;
import 'device_farm_test.dart' as device_farm_test;
import 'devices_test.dart' as devices_test;
import 'local_packages_test.dart' as local_packages_test;

main() {
  bundle_test.main();
  concurrent_jobs_test.main();
  device_farm_test.main();
  devices_test.main();
  local_packages_test.main();
}
