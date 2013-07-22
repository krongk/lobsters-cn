#encoding: utf-8
class Pushover
  cattr_accessor :API_KEY

  # this needs to be overridden in config/initializers/production.rb
  @@API_KEY = nil

  #xj: lazy added
  @@API_KEY = "eykBeBnYTwintxK1mUbGooSpCgCh7u"

  def self.push(user, device, params)
    if !@@API_KEY
      return
    end

    params[:message] = params[:message].to_s.match(/.{0,512}/m).to_s

    if params[:message] == ""
      params[:message] = "(No message)"
    end

    begin
      s = Sponge.new
      s.fetch("https://api.pushover.net/1/messages.json", :post, {
        :token => @@API_KEY,
        :user => user,
        :device => device
      }.merge(params))
    rescue => e
      Rails.logger.error "发送到pushover失败: #{e.inspect}"
    end
  end
end
