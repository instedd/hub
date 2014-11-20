class SimpleProperty
  attr_accessor :label
  attr_accessor :type
  attr_accessor :value

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

  def self.id(value)
    integer("Id", value)
  end

  def self.integer(label, value)
    new(label, :integer, value)
  end

  def self.name(value)
    string("Name", value)
  end

  def self.string(label, value)
    new(label, :string, value)
  end
end
