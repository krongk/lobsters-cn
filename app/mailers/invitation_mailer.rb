#encoding: utf-8
class InvitationMailer < ActionMailer::Base
  def invitation(invitation)
    @invitation = invitation

    mail(:to => invitation.email,
      :from => "ymzg.org <kenrome@gmail.com>",
      subject: "【义梦中国.随义】会员邀请函")
  end
end
