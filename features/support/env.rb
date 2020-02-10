require 'appium_lib'
require 'appium_lib/driver'

APP_PATH = 'MyApplication/app/build/outputs/apk/debug/app-debug.apk'
APP_PACKAGE = 'rajdeep.varma.com.myapplication'
APP_MAIN_ACTIVITY = ''
ESPRESSO_SERVER_PATH = 'io.appium.espressoserver.test_1.20.0_rajdeep.varma.com.myapplication_emulator-5554.apk'


def connected_devices
  lines = `adb devices`.split("\n")
  start_index = lines.index { |x| x =~ /List of devices attached/ } + 1
  lines[start_index..-1].collect { |l| l.split("\t").first }
end


def install_apps
  `#{adb_command} uninstall io.appium.espressoserver.test`
  `#{adb_command} uninstall #{APP_PACKAGE}`
  `#{adb_command} install #{APP_PATH}`
  `#{adb_command} install #{ESPRESSO_SERVER_PATH}`
end

def adb_command
  "adb -s #{adb_device_arg}"
end

def adb_device_arg
  ENV.fetch('ADB_DEVICE_ARG',connected_devices.first)
end

def reserve_port
  `#{adb_command} forward tcp:0 tcp:6790`.strip
end

def default_caps
  opts = {
      caps:
          {
              app: APP_PATH,
              platformName:           'Android',
              deviceName:             adb_device_arg,
              udid:                   adb_device_arg,
              appActivity:            'rajdeep.varma.com.myapplication.MainActivity',
              appPackage:             APP_PACKAGE,
              appWaitActivity:        '*',
              automationName:         'espresso',
              skipServerInstallation: true,
              newCommandTimeout:      0,
              system_port:            reserve_port,
              autoGrantPermissions:   true, # If noReset is true, this capability doesn't work.
              skipUnlock:             true,
              fullReset:              false,
              tmpDir:                 "#{Dir.tmpdir}/appium_temp/#{ENV.fetch('WORKER_INDEX', '0')}",
              # espressoBuildConfig:    'espresso_build_config.json',
          },
      appium_lib:
          {
              debug:      false,
              server_url: "http://localhost:#{ENV.fetch('APPIUM_PORT',4723)}/wd/hub",
          },
  }

  puts("USING SERVER = #{opts[:appium_lib][:server_url]}")
  puts("USING DEVICE = #{opts[:caps][:deviceName]}")
  puts("USING PORT = #{opts[:caps][:system_port]}")
  opts
end