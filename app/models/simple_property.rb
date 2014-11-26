class SimpleProperty
  attr_accessor :label
  attr_accessor :type
  attr_accessor :value

  def initialize(label, type, value)
    @label = label
    @type = type
    @value = value
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

  def reflect_property reflect_url_proc, user
    {label: label, type: type}
  end

  def self.reflect reflect_url_proc, properties, user
    Hash[properties.map do |k, v|
      [k, v.reflect_property(reflect_url_proc, user)]
    end]
  end
end
