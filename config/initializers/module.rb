class Module
  def not_nil?
    !nil?
  end

  def is_an? object
    is_a? object
  end

  def abstract(*args)
    args.each do |method|
      params = self.instance_method(method).parameters.map()do |p|
        case p.first
        when :rest
          "*#{p[1]}"
        when :opt
          "#{p[1]}="
        else
          p.last
        end
      end.join(', ') rescue ""
      self.class_eval <<-METHOD
        def #{method}(*args)
          raise self.class.name + " must define the method #{self.name}##{method}(#{params})"
        end
      METHOD
    end
  end
end
