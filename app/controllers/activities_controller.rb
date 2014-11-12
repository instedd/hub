class ActivitiesController < ApplicationController
  add_breadcrumb 'Activity', :activities_path

  expose(:activities) { current_user.activities }

  def index
  end
end
