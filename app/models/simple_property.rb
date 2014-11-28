class SimpleProperty
  attr_accessor :label
  attr_accessor :type
  attr_accessor :value

  def initialize(label, type, value)
    @label = label
    @type = type
    @value = value
  end

  def self.id(value=nil)
    integer("Id", value)
  end

  def self.integer(label, value=nil)
    new(label, :integer, value)
  end

  def self.name(value=nil)
    string("Name", value)
  end

  def self.string(label, value=nil)
    new(label, :string, value)
  end

  def reflect_property reflect_url_proc, user
    {label: label, type: type}
  end

  def self.struct members
    {
      type: {
        kind: :struct,
        members: members
      }
    }
  end

  def self.reflect reflect_url_proc, properties, user
    Hash[(properties || {}).map do |k, v|
      [k, v.reflect_property(reflect_url_proc, user)]
    end]
  end
end
