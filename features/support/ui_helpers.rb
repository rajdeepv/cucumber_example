class BusinessError < Exception
  def initialize(msg)
    super(msg)
  end
end

def some_more_things
  5.times do
    editor
    sleep 1
  end
end

def editor
  @driver.find_element(id: 'input')
end
