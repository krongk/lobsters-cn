#encoding: utf-8
class StoriesController < ApplicationController
  before_filter :require_logged_in_user_or_400,
    :only => [ :upvote, :downvote, :unvote, :preview ]

  before_filter :require_logged_in_user, :only => [ :delete, :create, :edit,
    :fetch_url_title, :new ]

  before_filter :find_story, :only => [ :destroy, :edit, :undelete, :update ]

  def create
    @title = "提交报道"
    @cur_url = "/stories/new"

    # we don't allow the url to be changed, so we have to set it manually
    @story = Story.new(params[:story].reject{|k,v| ["url","note"].include?(k) })
    @story.url = params[:story][:url]
    @story.user_id = @user.id
    #markdown keep blank
    @story.description = @story.description.gsub(/\n+/, "\n\n") unless @story.description.blank?

    if @story.save
      Vote.vote_thusly_on_story_or_comment_for_user_because(1, @story.id,
        nil, @user.id, nil)

      Countinual.count!("lobsters.stories.submitted", "+1")

      return redirect_to @story.comments_url

    else
      if @story.already_posted_story
        # consider it an upvote
        Vote.vote_thusly_on_story_or_comment_for_user_because(1,
          @story.already_posted_story.id, nil, @user.id, nil)

        flash[:success] = "该地址已经添加过了."

        return redirect_to @story.already_posted_story.comments_url
      end

      return render :action => "new"
    end
  end

  def destroy
    if !@story.is_editable_by_user?(@user)
      flash[:error] = "你不能修改此报道."
      return redirect_to "/"
    end

    @story.is_expired = true
    @story.editor_user_id = @user.id

    if params[:reason].present? && @story.user_id != @user.id
      @story.moderation_reason = params[:reason]
    end

    @story.save(:validate => false)

    redirect_to @story.comments_url
  end

  def edit
    if !@story.is_editable_by_user?(@user)
      flash[:error] = "你不能修改此报道."
      return redirect_to "/"
    end

    @title = "修改报道"
    1.times{ @story.assets.build } unless @story.assets.any?
  end

  def fetch_url_title
    s = Story.new
    s.url = params[:fetch_url]

    if (title = s.fetched_title(request.remote_ip)).present?
      return render :json => { :title => title }
    else
      return render :json => "error"
    end
  end

  def new
    @title = "提交报道"
    @cur_url = "/stories/new"

    @story = Story.new
    5.times{ @story.assets.build }

    if params[:url].present?
      @story.url = params[:url]

      if params[:title].present?
        @story.title = params[:title]
      end
    end
  end

  def preview
    # we don't allow the url to be changed, so we have to set it manually
    @story = Story.new(params[:story].reject{|k,v| k == "url" })
    @story.url = params[:story][:url]
    @story.user_id = @user.id
    @story.previewing = true

    @story.vote = 1
    @story.upvotes = 1

    @story.valid?

    return render :action => "new", :layout => false
  end

  def show
    @story = Story.find_by_short_id!(params[:id])

    if @story.can_be_seen_by_user?(@user)
      @title = @story.title
    else
      @title = "[报道已被删除]"
    end

    @short_url = @story.short_id_url

    @comments = Comment.ordered_for_story_or_thread_for_user(@story.id, nil,
      @user)

    respond_to do |format|
      format.html {
        @comment = Comment.new

        load_user_votes

        render :action => "show"
      }
      format.json {
        render :json => @story.as_json(:with_comments => @comments)
      }
    end
  end

  def show_comment
    @story = Story.find_by_short_id!(params[:id])

    @title = @story.title

    @showing_comment = Comment.find_by_short_id(params[:comment_short_id])

    if !@showing_comment
      flash[:error] = "没有找到评论."
      return redirect_to @story.comments_url
    end

    @comments = Comment.ordered_for_story_or_thread_for_user(@story.id,
      @showing_comment.thread_id, @user ? @user : nil)

    @comments.each do |c,x|
      if c.id == @showing_comment.id
        c.highlighted = true
        break
      end
    end

    @comment = Comment.new

    load_user_votes

    render :action => "show"
  end

  def undelete
    if !(@story.is_editable_by_user?(@user) &&
    @story.is_undeletable_by_user?(@user))
      flash[:error] = "没有权限."
      return redirect_to "/"
    end

    @story.is_expired = false
    @story.editor_user_id = @user.id
    @story.save(:validate => false)

    redirect_to @story.comments_url
  end

  def update
    if !@story.is_editable_by_user?(@user)
      flash[:error] = "你不能修改此报道."
      return redirect_to "/"
    end

    @story.is_expired = false
    @story.editor_user_id = @user.id

    @story.attributes = params[:story].except([:note, :url])
    if @story.url_is_editable_by_user?(@user)
      @story.url = params[:story][:url]
    end

    if @story.save
      return redirect_to @story.comments_url
    else
      return render :action => "edit"
    end
  end

  def unvote
    if !(story = Story.find_by_short_id(params[:story_id]))
      return render :text => "没有找到", :status => 400
    end

    Vote.vote_thusly_on_story_or_comment_for_user_because(0, story.id,
      nil, @user.id, nil)

    render :text => "ok"
  end

  def upvote
    if !(story = Story.find_by_short_id(params[:story_id]))
      return render :text => "没有找到", :status => 400
    end

    Vote.vote_thusly_on_story_or_comment_for_user_because(1, story.id,
      nil, @user.id, nil)

    render :text => "ok"
  end

  def downvote
    if !(story = Story.find_by_short_id(params[:story_id]))
      return render :text => "没有找到", :status => 400
    end

    if !Vote::STORY_REASONS[params[:reason]]
      return render :text => "无效的内容", :status => 400
    end

    Vote.vote_thusly_on_story_or_comment_for_user_because(-1, story.id,
      nil, @user.id, params[:reason])

    render :text => "ok"
  end

private
  def find_story
    if @user.is_moderator?
      @story = Story.find_by_short_id(params[:story_id] || params[:id])
    else
      @story = Story.find_by_user_id_and_short_id(@user.id,
        (params[:story_id] || params[:id]))
    end

    if !@story
      flash[:error] = "没有找到" <<
        "."
      redirect_to "/"
      return false
    end
  end

  def load_user_votes
    if @user
      if v = Vote.find_by_user_id_and_story_id_and_comment_id(@user.id,
      @story.id, nil)
        @story.vote = v.vote
      end

      @votes = Vote.comment_votes_by_user_for_story_hash(@user.id, @story.id)
      @comments.each do |c|
        if @votes[c.id]
          c.current_vote = @votes[c.id]
        end
      end
    end
  end
end
