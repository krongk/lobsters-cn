#encoding: utf-8
class InvitationMailer < ActionMailer::Base
  def invitation(invitation)
    @invitation = invitation

    mail(:to => invitation.email,
      :from => "yufuwu.org <kenrome@gmail.com>",
      subject: "【雨服务】会员邀请函")
  end
end
