#encoding: utf-8
class PasswordReset < ActionMailer::Base
  def password_reset_link(user, ip)
    @user = user
    @ip = ip

    mail(:to => user.email, :from => "yufuwu <kenrome@gmail.com>",
      :subject => "[雨服务] 密码重置")
  end
end
