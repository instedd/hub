module Action
  attr_reader :parent
  delegate :connector, to: :parent

  def args
    {}
  end

  def reflect(*)
    {
      label: label,
      args: args,
    }
  end

  def path
    "#{parent.path}/$actions/#{sub_path}"
  end

  abstract :sub_path
  abstract def invoke(args, user)
  end
end
