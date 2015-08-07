class JsonMapper
  def initialize(mapping)
    @mapping = mapping
  end

  def map_members(context, members)
    target = {}
    members.each do |key, value|
      mapped_value = map(context, value)
      target[key] = mapped_value unless mapped_value == :no_value
    end
    target
  end

  def map(context, mapping = @mapping)
    case mapping
    when String, Numeric
      context && context[mapping]
    when Array
      mapping.inject(context) do |context, key|
        map(context, key)
      end
    when Hash
      case mapping["type"]
      when "struct"
        map_members(context, mapping["members"])
      when "literal"
        mapping["value"] || :no_value
      end
    else
      raise "Unexpected mapping value: #{mapping.inspect}"
    end
  end
end
