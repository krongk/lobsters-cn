class Asset < ActiveRecord::Base
  belongs_to :story
  attr_accessible :asset
  has_attached_file :asset, :styles => { :large => "700x700>", :small => "80x80>" }
end
