class Asset < ActiveRecord::Base
  belongs_to :story
  attr_accessible :asset, :note

  after_create :expire_cache

  #this is for upyun
  has_attached_file :asset,
  { 
    :storage => :upyun, 
    # Set any other options according to paperclip
    :styles => { :small => "160x160#" }
  }

  ##This is for dropbox
  # has_attached_file :asset, 
  #   :styles => { :small => "40x40>" },
  #   :default_url => "/images/:style/missing.png",
  #   :storage => :dropbox,
  #   :dropbox_credentials => Rails.root.join("config/dropbox.yml"),
  #   :dropbox_options => { :path => proc { |style| "assets/#{style}/#{id}_#{asset.original_filename}" } }

  def expire_cache
    cache_index_path = File.join(Rails.root, 'public', 'p.html')
    cache_p_dir = File.join(Rails.root, 'public', 'p')
    FileUtils.rm_rf cache_index_path if File.exist?(cache_index_path)
    FileUtils.rm_rf cache_p_dir if File.exist?(cache_p_dir)
  end

end
