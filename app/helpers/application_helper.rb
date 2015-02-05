module ApplicationHelper
  def connector_human_name_for_type(type)
    "#{type}Connector".constantize.new.human_type
  end
end
