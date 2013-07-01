#encoding: utf-8
u = User.new(:username => "inruby", :email => "master@inruby.com", :password => "password")
u.is_admin = true
u.is_moderator = true
u.save

#init tags
t = Tag.new
t.tag = "Ruby"
t.save

t = Tag.new
t.tag = "RoR"
t.save

t = Tag.new
t.tag = "Gem"
t.save

t = Tag.new
t.tag = "Web"
t.save

t = Tag.new
t.tag = "部署"
t.save

t = Tag.new
t.tag = "工具"
t.save

t = Tag.new
t.tag = "项目"
t.save