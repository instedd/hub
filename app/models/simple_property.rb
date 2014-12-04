class SimpleProperty
  attr_accessor :label
  attr_accessor :type
  attr_accessor :value

  def initialize(label, type, value = nil)
    @label = label
    @type = type
    @value = value
  end

  def self.id(value = nil)
    integer("Id", value)
  end

  def self.integer(label, value = nil)
    new(label, :integer, value)
  end

  def self.name(value = nil)
    string("Name", value)
  end

  def self.string(label, value = nil)
    new(label, :string, value)
  end

  def reflect_property(context)
    {label: label, type: type}
  end

  def self.reflect context, properties
    Hash[(properties || {}).map do |k, v|
      [k, v.reflect_property(context)]
    end]
  end
end
