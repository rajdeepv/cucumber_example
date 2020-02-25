And(/^I am "([^"]*)"$/) do |name|
  add_note(name)

  if name == 'BATMAN'
    add_note('Genuine Failure')
    raise(BusinessError, 'Bad Luk Batman')
  else
    add_note('Must Pass')
  end

  some_more_things
end