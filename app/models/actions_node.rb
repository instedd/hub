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
    Hash[@parent.actions(user).map do |k, v|
        [k, {label: v.label, path: v.path}]
    end]
  end
end
