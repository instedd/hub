class JsonMapper
  def initialize(mapping)
    @mapping = mapping
  end

  def map_members(context, members)
    target = {}
    members.each do |key, value|
      target[key] = map(context, value)
    end
    target
  end

  def map(context, mapping = @mapping)
    if mapping.is_a?(String)
      context[mapping]
    elsif mapping.is_a?(Array)
      mapping.each do |key|
        context = context[key]
      end
      context
    else
      case mapping["type"]
      when "struct"
        map_members(context, mapping["members"])
      end
    end
  end
end
