#encoding: utf-8
class PasswordReset < ActionMailer::Base
  def password_reset_link(user, ip)
    @user = user
    @ip = ip

    mail(:to => user.email, :from => "ymzg.org <kenrome@gmail.com>",
      :subject => "[义梦中国.随义] 密码重置")
  end
end
