And(/^I am "([^"]*)"$/) do |name|
  add_note(name)
  add_note('Must Pass')
  some_more_things
end