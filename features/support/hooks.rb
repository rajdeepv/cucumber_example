require 'redis'

Before do
  install_apps
  @driver = Appium::Driver.new(default_caps, false)
  @driver.start_driver
end

After do
  @driver.quit_driver
end