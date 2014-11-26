module Action
  abstract :label, :sub_path
  attr_reader :parent
  delegate :connector, to: :parent

  def args(user)
    {}
  end

  def reflect_property(reflect_url_proc, user)
    {
      label: label,
      path: path,
      reflect_url: reflect_url_proc.call(path)
    }
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

  abstract def invoke(args, user)
  end
end
