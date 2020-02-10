puts "Starting appium for worker #{ENV['WORKER_INDEX']}"
pid = Process.spawn("./node_modules/.bin/appium --port #{ENV['APPIUM_PORT']}", [:out]=>"#{ENV['WORKER_INDEX']}_appium_log.txt")
