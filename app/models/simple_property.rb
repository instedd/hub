class SimpleProperty
  attr_accessor :label
  attr_accessor :type

  def initialize(label, type, value)
    @label = label
    @type = type
    @value = value
  end

  def path
    nil
  end

  def reflect_path
    nil
  end
end
