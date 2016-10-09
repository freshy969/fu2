class Api::UsersController < Api::ApiController

  def update
    user = current_user
    p = update_password_params
    if p[:password] && p[:password_confirmation] && p[:old_password]
      errors = {}
      user.update_password p[:old_password], p[:password], p[:password_confirmation]
      if user.errors.any? || !user.valid?
        render status: 401, json: {error: user.errors}
        return
      else
        user.save
      end
    else
      u = update_params
      user.update_attributes u if u.size > 0
    end

    current
  end

  def stats
    user = User.find params[:id]
    @view = Views::UserStats.new({
      user: user,
      site: @site
    })
    @view.finalize
  end

  def current
    render json: current_user.as_json.merge(email: current_user.email, type: "user-settings")
  end

  def update_params
    params.require(:user).permit(:email, :display_name, :avatar_url)
  end

  def update_password_params
    params.require(:user).permit(:old_password, :password, :password_confirmation)
  end

end
