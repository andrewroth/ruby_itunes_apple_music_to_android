require "rubygems"

require "byebug"
require "singleton"
require "yaml"

#require "tk"
#require "tkextlib/tktable"

require "net/ftp"
require "net/ftp/list"

Dir["app/**/*.rb"].each do |file|
  require_relative file
end

#MainUi.instance.start

start_all
