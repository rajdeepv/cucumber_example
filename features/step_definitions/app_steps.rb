And(/^I am "([^"]*)"$/) do |name|
  editor.send_keys(name)

  if name == 'Nagraj'
    sleep 2
    editor.send_keys("\nmust Fail for genuine reason")
    sleep 2
    raise(BusinessError, 'Bad Luk Nagraj') if name == 'Nagraj'
  else
    sleep 2
    editor.send_keys("\nmust PASS if all good")
  end

  some_more_things
end