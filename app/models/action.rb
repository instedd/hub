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
    if parent.path.present?
      "#{parent.path}/$actions/#{sub_path}"
    else
      "$actions/#{sub_path}"
    end
  end

  abstract def invoke(args, user)
  end
end
