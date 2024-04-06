require "rubygems"

require "byebug"
require "singleton"
require "yaml"

require "tk"
require "tkextlib/tktable"

require "net/ftp"
require "net/ftp/list"

Dir["app/**/*.rb"].each do |file|
  puts file
  require_relative file
end

=begin
require_relative "app/models/log"
require_relative "app/models/settings"
require_relative "app/models/device"
require_relative "app/models/library"

require_relative "app/views/has_status"
require_relative "app/views/main_ui"
require_relative "app/views/select_music_directory_ui"
=end

MainUi.instance.start

#@device = Device.new
#@device.update_cache

#@library = Library.new
#@library.match_device_tracks
#@library.generate_playlists

#@device.upload_playlists(@library)
