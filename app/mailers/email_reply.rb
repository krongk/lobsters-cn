class EmailReply < ActionMailer::Base
  default :from => "nobody@ymzg.org"

  def reply(comment, user)
    @comment = comment
    @user = user

    mail(:to => user.email, :from => "随义 <nobody@ymzg.org>",
      :subject => "[随义] #{comment.user.username} 回复 " <<
      "#{comment.story.title}")
  end

  def mention(comment, user)
    @comment = comment
    @user = user

    mail(:to => user.email, :from => "随义 <nobody@ymzg.org>",
      :subject => "[随义] #{comment.user.username} 提到 " <<
      "#{comment.story.title}")
  end
end
