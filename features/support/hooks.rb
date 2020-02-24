require 'redis'

Before do
  install_apps
  @driver = Appium::Driver.new(default_caps, false)
  @driver.start_driver
end

After do |scenario|
  @driver.quit_driver
  redis = Redis.new(url: ENV['REDIS'])
  queue = ENV.fetch('TEST_BATCH_ID', nil)
  if queue && scenario.failed?
    details = {"#{scenario.location.file}:#{scenario.location.line}" => {:status => scenario.status,
                                                                         :exception_class => scenario.exception.class,
                                                                         :exception_message => scenario.exception.message}
    }
    redis.lpush(queue, details.to_json)
  end
end