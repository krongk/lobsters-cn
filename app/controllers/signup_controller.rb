#encoding: utf-8
class SignupController < ApplicationController
  before_filter :require_logged_in_user, :only => :invite

  def index
    if @user
      flash[:error] = "你已经登录了."
      return redirect_to "/"
    end

    @title = "Signup"
  end

  def invited
    if @user
      flash[:error] = "你已经登录了."
      return redirect_to "/"
    end

    if !(@invitation = Invitation.find_by_code(params[:invitation_code].to_s))
      flash[:error] = "邀请码无效，或者已过期"
      return redirect_to "/signup"
    end

    @title = "注册"

    @new_user = User.new
    @new_user.email = @invitation.email

    render :action => "invited"
  end

  def signup
    if !(@invitation = Invitation.find_by_code(params[:invitation_code].to_s))
      flash[:error] = "邀请码无效，或者已过期."
      return redirect_to "/signup"
    end

    @title = "注册"

    @new_user = User.new(params[:user])
    @new_user.invited_by_user_id = @invitation.user_id

    if @new_user.save
      @invitation.destroy
      session[:u] = @new_user.session_token
      flash[:success] = "欢迎你, #{@new_user.username}！"

      Countinual.count!("lobsters.users.created", "+1")

      return redirect_to "/signup/invite"
    else
      render :action => "invited"
    end
  end
end
