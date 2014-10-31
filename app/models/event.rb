module Event
  def args
    {}
  end

  def reflect(*)
    {
      label: label,
      args: args,
    }
  end
end
