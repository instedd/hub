class ActionsNode
  def initialize(parent)
    @parent = parent
  end

  def lookup(path)
    return self if path.empty?

    action_name = path.shift
    @parent.actions[action_name]
  end

  def reflect
    Hash[@parent.actions.map do |k, v|
        [k, {label: v.label, path: v.path}]
    end]
  end
end
