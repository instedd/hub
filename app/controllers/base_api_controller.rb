class BaseApiController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  around_filter :rescue_with_error_detail

  def rescue_with_error_detail
    yield
  rescue => ex
    code = (ex.message[/\d{3}/] || 500).to_i
    render json: {message: ex.message, error_code: code}, status: code
  end
end
