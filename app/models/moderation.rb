#encoding: utf-8
class Moderation < ActiveRecord::Base
  belongs_to :moderator,
    :class_name => "User",
    :foreign_key => "moderator_user_id"
  belongs_to :story
  belongs_to :comment
  belongs_to :user

  attr_accessible nil

  after_create :send_message_to_moderated

  def send_message_to_moderated
    m = Message.new
    m.author_user_id = self.moderator_user_id

    # mark as deleted by author so they don't fill up moderator message boxes
    m.deleted_by_author = true

    if self.story
      m.recipient_user_id = self.story.user_id
      m.subject = "你提交的报道被会长编辑过了"
      m.body = "你提交的报道[#{self.story.title}](" <<
        "#{self.story.comments_url}) 被会长编辑过，" <<
        "修改日志:\n" <<
        "\n" <<
        "> *#{self.action}*\n"

      if self.reason.present?
        m.body << "\n" <<
          "修改的原因:\n" <<
          "\n" <<
          "> *#{self.reason}*"
      end

    elsif self.comment
      m.recipient_user_id = self.comment.user_id
      m.subject = "你提交的评论被会长编辑过了"
      m.body = "你提交的评论 [#{self.comment.story.title}](" <<
        "#{self.comment.story.comments_url}) 被修改如下:\n" <<
        "\n" <<
        "> *#{self.comment.comment}*"

      if self.reason.present?
        m.body << "\n" <<
          "修改原因:\n" <<
          "\n" <<
          "> *#{self.reason}*"
      end

    else
      # no point in alerting deleted users, they can't login to read it
      return
    end

    m.save
  end
end
