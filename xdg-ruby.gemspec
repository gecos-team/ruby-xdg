Gem::Specification.new do |s|
  s.name        = 'xdg-ruby'
  s.version     = '0.1'
  s.date        = '2013-02-27'
  s.summary     = "A Ruby XDG Library"
  s.description = "A Ruby XDG Library."
  s.authors     = ["L. Ramsey"]
  s.email       = 'christopherlramsey@gmx.us'
  s.homepage    = 'https://github.com/dark-yux/xdg-ruby'
  s.license     = 'Copyright (c) 2012 All rights reserved'
  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "libxml-ruby"
  s.add_runtime_dependency "tzinfo"
  s.files       = [
    "lib/xdg.rb",
    "lib/xdg/applications.rb", 
    "lib/xdg/core.rb", 
    "lib/xdg/icons.rb", 
    "lib/xdg/applications.rb", 
    "lib/xdg/menus.rb", 
    "lib/xdg/constants.rb", 
    "lib/xdg/trash.rb",
    "README.md"
  ]
end
