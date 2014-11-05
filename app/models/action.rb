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

  def invoke(args)
  end
end
