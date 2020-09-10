And(/^I am "([^"]*)"$/) do |name|
  add_note(name)
  # raise(BusinessError, 'Shaktiman is dead') if name == 'Shaktiman'
  add_note('Must Pass')
  some_more_things
end