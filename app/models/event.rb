module Event
  def args
    {}
  end

  def reflect
    {
      name: name,
      args: args,
    }
  end
end
