class ComposedProperty
  attr_accessor :members
  attr_accessor :open

  def initialize(members, open=false)
    @members = members
    @open = open
  end

  def reflect_property reflect_url_proc, user
    struct = {
      type: {
        kind: :struct,
        members: SimpleProperty.reflect(reflect_url_proc, members, user),
      }
    }
    struct[:type][:open] = true if open
    struct
  end
end
