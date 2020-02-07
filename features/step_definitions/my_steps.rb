# frozen_string_literal: true

Given(/^I am test "([^"]*)"$/) do |test|
  puts "Step from test #{test}"
end

And(/^I sleep for "([^"]*)" seconds$/) do |time|
  require 'net/http'
  uri = URI("http://localhost:#{ENV['APPIUM_PORT']}/wd/hub/status")
  p Net::HTTP.get(uri)
  sleep time.to_i
end

And(/^I fail$/) do
  require 'redis'
  redis = Redis.new(url: ENV['REDIS'])
  redis.lpush("kill-worker-#{ENV['WORKER_INDEX']}", 'a')
  raise('LOL')
end