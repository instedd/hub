class ComposedProperty
  attr_accessor :members
  attr_accessor :open

  def initialize(members, open: false)
    @members = members
    @open = open
  end

  def reflect_property(context)
    struct = {
      type: {
        kind: :struct,
        members: SimpleProperty.reflect(context, members),
      }
    }
    struct[:type][:open] = true if open
    struct
  end
end
