#encoding: utf-8
u = User.new(:username => "inruby", :email => "master@inruby.com", :password => "kenrome")
u.is_admin = true
u.is_moderator = true
u.save

u = User.new(:username => "Xuejiang", :email => "xuejiang.avvo@gmail.com", :password => "kenrome")
u.is_admin = true
u.save

u = User.new(:username => "kenrome", :email => "kenrome@163.com", :password => "kenrome")
u.is_moderator = true
u.save

u = User.new(:username => "nasha", :email => "nashayu@163.com", :password => "kenrome")
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