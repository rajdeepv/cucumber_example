And(/^I am "([^"]*)"$/) do |name|
  add_note(name)
  sleep 2

  if name == 'Nagraj'
    add_note("must Fail for genuine reason")
    sleep 2
    raise(BusinessError, 'Bad Luk Nagraj')
  else
    add_note("must PASS if all good")
  end

  some_more_things
end