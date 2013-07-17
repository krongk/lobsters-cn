class Asset < ActiveRecord::Base
  belongs_to :story
  attr_accessible :asset
  has_attached_file :asset, 
    :styles => { :small => "40x40>" },
    :default_url => "/images/:style/missing.png",
    :storage => :dropbox,
    :dropbox_credentials => Rails.root.join("config/dropbox.yml"),
    :dropbox_options => { :path => proc { |style| "assets/#{style}/#{id}_#{asset.original_filename}" } }
end
