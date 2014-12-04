class ActionsNode
  def initialize(parent)
    @parent = parent
  end

  def lookup(path, context)
    return self if path.empty?

    action_name = path.shift
    @parent.actions(context)[action_name]
  end

  def reflect(context)
    SimpleProperty.reflect context, @parent.actions(context)
  end
end
