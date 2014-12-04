module Action
  abstract :label, :sub_path
  attr_reader :parent
  delegate :connector, to: :parent

  def args(context)
    {}
  end

  def reflect_property(context)
    {
      label: label,
      path: path,
      reflect_url: context.reflect_url(path)
    }
  end

  def reflect(context)
    {
      label: label,
      args: args(context),
    }
  end

  def path
    if parent.path.present?
      "#{parent.path}/$actions/#{sub_path}"
    else
      "$actions/#{sub_path}"
    end
  end

  abstract def invoke(args, context)
  end
end
