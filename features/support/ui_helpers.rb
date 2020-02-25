class BusinessError < Exception
  def initialize(msg)
    super(msg)
  end
end

def some_more_things
  5.times do |index|
    add_note("#{index+1}")
    sleep 1
  end
  add_note("PASS!")
end

def add_note(note)
  @driver.find_element(id: 'input').send_keys("#{note}")
  `#{adb_command} shell input keyevent 66`
end
