module AngularHelper
  def init_scope(options)
    s = ""
    options.each do |k,v|
      s << k.to_s << "=" << v.to_json << ";"
    end

    s
  end
end
