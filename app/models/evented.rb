module Evented
  def reflect_event(event)
    events[event].reflect
  end
end
