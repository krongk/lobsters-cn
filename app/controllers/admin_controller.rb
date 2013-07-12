#encoding: utf-8
class BizEmail < ActiveRecord::Base
  belongs_to :user
  self.per_page = 50

  scope :not_mailed, -> { where is_processed: 'n' }
  scope :successed, -> { where is_processed: 'y' }
  scope :failed, -> { where is_processed: 'f' }
  scope :skipped, -> { where is_processed: 's' }
end

class AdminController < ApplicationController
	before_filter :require_logged_in_user

  def index
  end

  def biz_email
  	@biz_emails = BizEmail.where(:user_id => @user.id)
  	case params[:scope]
  	when "not_mailed"
  		@biz_emails = @biz_emails.not_mailed
  	when "successed"
  		@biz_emails = @biz_emails.successed
  	when "failed"
  		@biz_emails = @biz_emails.failed
  	when "skipped"
  		@biz_emails = @biz_emails.skipped
  	end
  	@biz_emails = @biz_emails.page(params[:page])
  end

  def sent_biz_email
  	# "biz_email_ids"=>["191", "192"]
  	biz_email_ids = params[:biz_email_ids] || []

  	flag = nil
  	result = {:success => [], :error => [], :skip => []}
  	BizEmail.where(:id => biz_email_ids).each do |biz_email|
  		next if biz_email.is_processed == 'y'
  		flag = 'f'

  		biz_email.email = biz_email.email.to_s.gsub(/\s*/m, '')
  		if biz_email.email.blank? || biz_email.email !~ /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/
  			flag = 's'
  			result[:skip] << biz_email.id
  		else
		    i = Invitation.find_or_initialize_by_email(biz_email.email)
		    i.user_id = @user.id
		    i.memo = "#{biz_email.name}, #{params[:memo]}"

		    begin
		      if i.save
		        i.send_email
		        result[:success] << biz_email.id
		        flag = 'y'
		      else
		      	raise "Invitation save error"
		      end
		    rescue => ex
		    	Rails.logger.error ex.message
		      result[:error] << biz_email.id
		    end
		  end 
	    biz_email.is_processed = flag
	    biz_email.save
	  end

	  flash[:success] = " 失败：" << result[:error].size.to_s
	  flash[:success] = flash[:success] << " 成功：" << result[:success].size.to_s
	  flash[:success] = flash[:success] << " 跳过：" << result[:skip].size.to_s

    if params[:return_home]
      return redirect_to "/"
    else
      return redirect_to "/admin/biz_email"
    end
  end
end
