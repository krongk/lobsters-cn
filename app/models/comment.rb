#encoding: utf-8
class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :story
  has_many :votes,
    :dependent => :delete_all
  belongs_to :parent_comment,
    :class_name => "Comment"
  has_one :moderation,
    :class_name => "Moderation"

  attr_accessible :comment, :moderation_reason

  attr_accessor :parent_comment_short_id, :current_vote, :previewing,
    :indent_level, :highlighted

  before_create :assign_short_id_and_upvote, :assign_initial_confidence
  after_create :assign_votes, :mark_submitter, :deliver_reply_notifications,
    :deliver_mention_notifications
  after_destroy :unassign_votes

  MAX_EDIT_MINS = 45

  define_index do
    indexes comment
    indexes user.username, :as => :author

    has "(upvotes - downvotes)", :as => :score, :type => :integer,
      :sortable => true

    has is_deleted
    has created_at

    where "is_deleted = 0 AND is_moderated = 0"
  end

  validate do
    self.comment.to_s.strip == "" &&
      errors.add(:comment, "不能为空.")

    self.user_id.blank? &&
      errors.add(:user_id, "不能为空.")

    self.story_id.blank? &&
      errors.add(:story_id, "不能为空.")

    (m = self.comment.to_s.strip.match(/\A(t)his([\.!])?$\z/i)) &&
      errors.add(:base, (m[1] == "T" ? "N" : "n") + "ope" + m[2].to_s)
  end

  def self.regenerate_markdown
    Comment.record_timestamps = false

    Comment.all.each do |c|
      c.markeddown_comment = c.generated_markeddown_comment
      c.save(:validate => false)
    end

    Comment.record_timestamps = true

    nil
  end

  def as_json(options = {})
    h = super(:only => [
      :short_id,
      :created_at,
      :updated_at,
      :is_deleted,
      :is_moderated,
    ])
    h[:score] = score

    if self.is_gone?
      h[:comment] = "<em>#{self.gone_text}</em>"
    else
      h[:comment] = markeddown_comment
    end

    h[:url] = url
    h[:indent_level] = indent_level
    h[:commenting_user] = user
    h
  end

  def assign_short_id_and_upvote
    self.short_id = ShortId.new(self.class).generate
    self.upvotes = 1
  end

  def assign_votes
    Vote.vote_thusly_on_story_or_comment_for_user_because(1, self.story_id,
      self.id, self.user.id, nil, false)

    self.story.update_comment_count!
  end

  def vote_summary
    r_counts = {}
    Vote.where(:comment_id => self.id).each do |v|
      r_counts[v.reason.to_s] ||= 0
      r_counts[v.reason.to_s] += v.vote
    end

    r_counts.keys.sort.map{|k|
      k == "" ? "+#{r_counts[k]}" : "#{r_counts[k]} #{Vote::COMMENT_REASONS[k]}"
    }.join(", ")
  end

  def is_gone?
    is_deleted? || is_moderated?
  end

  def gone_text
    if self.is_moderated?
      "该线索被会长删除， " <<
        self.moderation.try(:moderator).try(:username).to_s << ": " <<
        (self.moderation.try(:reason) || "没有说明原因")
    else
      "评论已被移除"
    end
  end

  def mark_submitter
    Keystore.increment_value_for("user:#{self.user_id}:comments_posted")
  end

  def deliver_mention_notifications
    self.plaintext_comment.scan(/\B\@([\w\-]+)/).flatten.uniq.each do |mention|
      if u = User.find_by_username(mention)
        if u.id == self.user.id
          next
        end

        begin
          if u.email_mentions?
            EmailReply.mention(self, u).deliver
          end

          if u.pushover_mentions? && u.pushover_user_key.present?
            Pushover.push(u.pushover_user_key, u.pushover_device, {
              :title => "提醒：#{self.user.username} 关于 " <<
                self.story.title,
              :message => self.plaintext_comment,
              :url => self.url,
              :url_title => "回复#{self.user.username}",
            })
          end
        rescue => e
          Rails.logger.error "失败，当尝试发送提醒 " <<
            "#{u.username}: #{e.message}"
        end
      end
    end
  end

  def deliver_reply_notifications
    if self.parent_comment_id && (u = self.parent_comment.try(:user)) &&
    u.id != self.user.id
      begin
        if u.email_replies?
          EmailReply.reply(self, u).deliver
        end

        if u.pushover_replies? && u.pushover_user_key.present?
          Pushover.push(u.pushover_user_key, u.pushover_device, {
            :title => "来自#{self.user.username} 关于 " <<
              "#{self.story.title}的回复",
            :message => self.plaintext_comment,
            :url => self.url,
            :url_title => "回复#{self.user.username}",
          })
        end
      rescue => e
        Rails.logger.error "失败，当尝试发送提醒 " <<
          "#{u.username}: #{e.message}"
      end
    end
  end

  def delete_for_user(user)
    Comment.record_timestamps = false

    self.is_deleted = true

    if user.is_moderator? && user.id != self.user_id
      self.is_moderated = true

      m = Moderation.new
      m.comment_id = self.id
      m.moderator_user_id = user.id
      m.action = "删除评论"
      m.save
    end

    self.save(:validate => false)
    Comment.record_timestamps = true

    self.story.update_comment_count!
  end

  def undelete_for_user(user)
    Comment.record_timestamps = false

    self.is_deleted = false

    if user.is_moderator?
      self.is_moderated = false

      if user.id != self.user_id
        m = Moderation.new
        m.comment_id = self.id
        m.moderator_user_id = user.id
        m.action = "恢复评论"
        m.save
      end
    end

    self.save(:validate => false)
    Comment.record_timestamps = true

    self.story.update_comment_count!
  end

  def give_upvote_or_downvote_and_recalculate_confidence!(upvote, downvote)
    self.upvotes += upvote.to_i
    self.downvotes += downvote.to_i

    Comment.connection.execute("UPDATE #{Comment.table_name} SET " <<
      "upvotes = COALESCE(upvotes, 0) + #{upvote.to_i}, " <<
      "downvotes = COALESCE(downvotes, 0) + #{downvote.to_i}, " <<
      "confidence = '#{self.calculated_confidence}' WHERE id = " <<
      "#{self.id.to_i}")
  end

  # http://evanmiller.org/how-not-to-sort-by-average-rating.html
  # https://github.com/reddit/reddit/blob/master/r2/r2/lib/db/_sorts.pyx
  def calculated_confidence
    n = (upvotes + downvotes).to_f
    if n == 0.0
      return 0
    end

    z = 1.281551565545 # 80% confidence
    p = upvotes.to_f / n

    left = p + (1 / ((2.0 * n) * z * z))
    right = z * Math.sqrt((p * ((1.0 - p) / n)) + (z * (z / (4.0 * n * n))))
    under = 1.0 + ((1.0 / n) * z * z)

    return (left - right) / under
  end

  def assign_initial_confidence
    self.confidence = self.calculated_confidence
  end

  def unassign_votes
    self.story.update_comment_count!
  end

  def score
    self.upvotes - self.downvotes
  end

  def generated_markeddown_comment
    Markdowner.to_html(self.comment)
  end

  def comment=(com)
    self[:comment] = com.to_s.rstrip
    self.markeddown_comment = self.generated_markeddown_comment
  end

  def plaintext_comment
    # TODO: linkify then strip tags and convert entities back
    comment
  end

  def has_been_edited?
    self.updated_at && (self.updated_at - self.created_at > 1.minute)
  end

  def self.ordered_for_story_or_thread_for_user(story_id, thread_id, user)
    parents = {}

    if thread_id
      cs = [ "thread_id = ?", thread_id ]
    else
      cs = [ "story_id = ?", story_id ]
    end

    #Comment.find(:all, :conditions => cs, :order => "confidence DESC",:include => :user).each do |c|
    Comment.includes(:user).where(cs).order("confidence DESC").each do |c|
      (parents[c.parent_comment_id.to_i] ||= []).push c
    end

    # top-down list of comments, regardless of indent level
    ordered = []

    recursor = lambda{|comment,level|
      if comment
        comment.indent_level = level
        ordered.push comment
      end

      # for each comment that is a child of this one, recurse with it
      (parents[comment ? comment.id : 0] || []).each do |child|
        recursor.call(child, level + 1)
      end
    }
    recursor.call(nil, 0)

    # for deleted comments, if they have no children, they can be removed from
    # the tree.  otherwise they have to stay and a "[deleted]" stub will be
    # shown
    new_ordered = []
    ordered.each_with_index do |c,x|
      if c.is_gone?
        if ordered[x + 1] && (ordered[x + 1].indent_level > c.indent_level)
          # we have child comments, so we must stay
        elsif user && (user.is_moderator? || c.user_id == user.id)
          # admins and authors should be able to see their deleted comments
        else
          # drop this one
          next
        end
      end

      new_ordered.push c
    end

    # for moderated threads, remove the entire sub-tree at the moderation point
    do_reject = false
    deleted_indent_level = 0
    new_ordered.reject!{|c|
      if do_reject && (c.indent_level > deleted_indent_level)
        true
      else
        if c.is_moderated?
          do_reject = true
          deleted_indent_level = c.indent_level
        else
          do_reject = false
        end

        false
      end
    }

    new_ordered
  end

  def is_editable_by_user?(user)
    if user && user.id == self.user_id
      if self.is_moderated?
        return false
      else
        return (Time.now.to_i - (self.updated_at ? self.updated_at.to_i :
          self.created_at.to_i) < (60 * MAX_EDIT_MINS))
      end
    else
      return false
    end
  end

  def is_deletable_by_user?(user)
    if user && user.is_moderator?
      return true
    elsif user && user.id == self.user_id
      return true
    else
      return false
    end
  end

  def is_undeletable_by_user?(user)
    if user && user.is_moderator?
      return true
    elsif user && user.id == self.user_id && !self.is_moderated?
      return true
    else
      return false
    end
  end

  def short_id_url
    self.story.short_id_url + "/_/comments/#{self.short_id}"
  end

  def url
    self.story.comments_url + "/comments/#{self.short_id}"
  end
end
