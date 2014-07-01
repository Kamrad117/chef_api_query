class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from SocketError, with: :socket_error

private 
  def socket_error
    flash[:alert] = 'Socket Error, unable to connect to chef server'
    redirect_to error_path
  end
end
