#encoding: utf-8
class InvitationsController < ApplicationController
  before_filter :require_logged_in_user

  def create
    i = Invitation.new
    i.user_id = @user.id
    i.email = params[:email]
    i.memo = params[:memo]

   # begin
      if i.save
        i.send_email
        flash[:success] = "邮件成功发送到了：" <<
          params[:email].to_s << "."
      else
      #  raise
      end
    # rescue
    #   flash[:error] = "邀请失败，请检查邮箱地址是否正确" <<
    #     "."
    # end

    if params[:return_home]
      return redirect_to "/"
    else
      return redirect_to "/settings"
    end
  end
end
