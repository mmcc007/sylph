const wd = require('wd');
const assert = require('assert');

const opts = {
  port: 4723,
  capabilities: {
    platformName: process.env.DEVICEFARM_DEVICE_PLATFORM_NAME,
    platformVersion: process.env.DEVICEFARM_DEVICE_OS_VERSION,
    deviceName: process.env.DEVICEFARM_DEVICE_NAME,
    app: process.env.DEVICEFARM_APP_PATH,
    automationName: 'UiAutomator2',
    noReset: false,
    fullReset: true,
    newCommandTimeout: 180,
    appWaitActivity: '*',
    appWaitPackage: '*'
  }
};

async function runTest() {
  const driver = wd.promiseChainRemote(opts);
  let testPassed = false;

  try {
    console.log('Initializing driver with capabilities:', JSON.stringify(opts.capabilities));
    await driver.init(opts.capabilities);
    console.log('App started successfully');

    // Wait for app to load
    console.log('Waiting for app to load...');
    await driver.sleep(15000);

    // Get app state information
    console.log('Getting app state information...');
    const currentPackage = await driver.getCurrentPackage();
    console.log('Current package:', currentPackage);

    const currentActivity = await driver.getCurrentActivity();
    console.log('Current activity:', currentActivity);

    // Log app hierarchy
    console.log('Getting app hierarchy...');
    const source = await driver.source();
    console.log('App hierarchy:', source);

    // Try to find Flutter elements
    const elements = await driver.elementsByClassName('android.widget.FrameLayout');
    console.log(`Found ${elements.length} FrameLayout elements`);

    // Basic verification
    assert(currentPackage, 'App package should be available');
    assert(currentActivity, 'App should have an active activity');
    assert(elements.length > 0, 'App should have at least one FrameLayout element');

    testPassed = true;
    console.log('Test passed!');
  } catch (error) {
    console.error('Test failed with error:', error);
    throw error;
  } finally {
    if (!testPassed) {
      console.log('Test did not pass. Getting final app state...');
      try {
        const finalSource = await driver.source();
        console.log('Final app state:', finalSource);
      } catch (e) {
        console.error('Could not get final app state:', e);
      }
    }
    console.log('Cleaning up...');
    await driver.quit();
  }
}

runTest().catch(error => {
  console.error('Test failed:', error);
  process.exit(1);
});
