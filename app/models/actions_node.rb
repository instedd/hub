class ActionsNode
  def initialize(parent)
    @parent = parent
  end

  def lookup(path, user)
    return self if path.empty?

    action_name = path.shift
    @parent.actions(user)[action_name]
  end

  def reflect(proc, user)
    SimpleProperty.reflect proc, @parent.actions(user), user
  end
end
