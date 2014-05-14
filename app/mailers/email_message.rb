class EmailMessage < ActionMailer::Base
  default :from => "nobody@ymzg.org"

  def notify(message, user)
    @message = message
    @user = user

    mail(:to => user.email, :from => "随义 <nobody@ymzg.org>",
      :subject => "[随义] 私信来自 " <<
        "#{message.author.username}: #{message.subject}")
  end
end
