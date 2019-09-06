Given(/^I am test "([^"]*)"$/) do |test|
  puts "Step from test #{test}"
end

And(/^I sleep for "([^"]*)" seconds$/) do |time|
  sleep time.to_i
end