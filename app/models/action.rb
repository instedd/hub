module Action
  attr_reader :parent
  delegate :connector, to: :parent

  def args(user)
    {}
  end

  def reflect(proc, user)
    {
      label: label,
      args: args(user),
    }
  end

  def path
    "#{parent.path}/$actions/#{sub_path}"
  end

  abstract :sub_path
  abstract def invoke(args, user)
  end
end
