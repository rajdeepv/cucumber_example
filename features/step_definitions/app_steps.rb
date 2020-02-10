Given(/^I start the app$/) do
  install_apps
  @driver = Appium::Driver.new(default_caps, false)
  @driver.start_driver
  sleep 5
end