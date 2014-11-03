class HomeController < ApplicationController
  skip_before_action :authenticate_user!

  def index
  end

  def angular_template
    render "angular/#{params[:path]}", layout: false
  end
end
