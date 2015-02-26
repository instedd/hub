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

  def self.boolean(label, value = nil)
    new(label, :boolean, value)
  end

  def self.integer(label, value = nil)
    new(label, :integer, value)
  end

  def self.numeric(label, value = nil)
    new(label, :numeric, value)
  end

  def self.float(label, value = nil)
    new(label, :float, value)
  end

  def self.datetime(label, value = nil)
    new(label, :datetime, value)
  end

  def self.location(label, value = nil)
    new(label, :location, value)
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
      [k, v.is_a?(Hash) ? v : v.reflect_property(context)]
    end]
  end
end
