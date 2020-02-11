class BusinessError < Exception
  def initialize(msg)
    super(msg)
  end
end

And(/^I am "([^"]*)"$/) do |name|
  @driver.find_element(id:'input').send_keys(name)
  @driver.find_element(id:'input').send_keys("\nwill fail") if name == "Nagraj"
  raise BusinessError, "Bad Luk Nagraj" if name == 'Nagraj'
  sleep 10
  puts @driver.find_element(id:'input').text == name
end