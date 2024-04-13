require "nokogiri"
require "cgi"

class Library
  include Logs
  include SetsProgress
  include SetsStatus

  LOCAL_PLAYLISTS_DIR = "./playlists_from_library"

  attr_accessor :tracks, :playlists, :tracks_by_size, :music_folder

  def initialize(xml_path = "Library.xml")
    log("Loading #{xml_path}...")
    @doc = File.open(xml_path) { |f| Nokogiri::XML(f) };
    log("Done")
    @music_folder = @doc.xpath('/plist/dict/key[text()="Music Folder"]').first.next_element.text
    set_progress_total
    load_tracks
    load_playlists
    log("progress #{MainUi.instance.progress.value}/#{MainUi.instance.progress.maximum}")
    progress_complete
  end

  def set_progress_total
    tracks_count = @doc.xpath('/plist/dict/key[text()="Tracks"]').first.next_element.search("> key").count
    playlists_count = @doc.xpath('/plist/dict/key[text()="Playlists"]').first.next_element.xpath("dict").count
    set_progress_max(tracks_count + playlists_count)
  end

  def load_tracks
    key = nil
    @tracks = {}
    @doc.xpath('/plist/dict/key[text()="Tracks"]').first.next_element.children.collect do |el|
      case el.name
      when "key"
        key = el.text
      when "text"
        #puts el.text
      when "dict"
        track_id = el.xpath("key[text()='Track ID']").first.next_element.text
        name = el.xpath("key[text()='Name']").first.next_element.text
        size = el.xpath("key[text()='Size']").first.next_element.text.to_i
        location = el.xpath("key[text()='Location']").first
        if location
          location = location.next_element.text
        else
          # an item without a location key is not something we can copy to the device
          progress_step
          next
        end

        if sub_start = location.index(@music_folder)
          device_location = location[(sub_start + @music_folder.length)..location.length]
        else
          #device_location = File.join(File.dirname(location).split("/").last(3))
          device_location = File.join(location.split("/").last(3))
        end

        #location = CGI.unescape(location)
        #device_location = CGI.unescape(device_location)
        location.gsub!("%20", " ")
        device_location.gsub!("%20", " ")

        # if location now starts with Music/ or /Music/, cut that out
        location.sub!(/^\/?Music\//, "")
        device_location.sub!(/^\/?Music\//, "")

        # try to get a proper file path that will actually exist
        location.gsub!(/^file:\/\/(localhost\/)?/, "")

        # TODO: better to raise and catch this, handle all errors into a status instead of just this one
        unless File.exists?(location)
          msg = "Error loading library: File #{location.inspect} does not exist"
          set_main_status(msg)
          raise(msg)
        end

        log("device_location: #{device_location}")
        byebug if device_location.start_with?("file:")
        @tracks[track_id] = { id: track_id, name: name, size: size, location: location, device_location: device_location }

        progress_step
      end
    end 

    # l.tracks.collect{|k,v| v[:size] }.group_by(&:itself).find_all{ |k, v| v.length > 1 }.collect(&:first)
    @tracks_by_size = @tracks.values.group_by{ |attributes| attributes[:size] }
  end

  def match_device_tracks(device_cache)
    @tracks.each_pair do |track_id, attributes|
      attributes[:on_device] = false
    end

    device_cache.each do |path, entries|
      entries.each do |entry|
        next unless entry.file?

        full_path = File.join(path, entry.basename)
        log("Search for #{entry.filesize} (#{full_path})")
        if tracks = @tracks_by_size[entry.filesize]
          if tracks.length == 1
            log("   -> #{tracks}")
            @tracks[tracks.first[:id]][:device_location] = full_path
            @tracks[tracks.first[:id]][:on_device] = true
          elsif tracks.length > 1
            log("MULTIPLE MATCHES FOR #{File.join(path, entry.basename)}")
            track = tracks.detect{ |t| File.basename(t[:location]).gsub("%20", "") }

            if track
              log("Found match for #{full_path}: #{tracks}")
              @tracks[track[:id]][:device_location] = full_path
              @tracks[track[:id]][:on_device] = true
            else
              byebug
              # still no match
            end
          end
        end
      end
    end
  end

  def load_playlists
    @playlists = []
    @doc.xpath('/plist/dict/key[text()="Playlists"]').first.next_element.xpath("dict").each do |el|
      # el is a dict with keys, and "Playlist Items" is where the track ids are
      name = el.xpath("key[text()='Name']").first.next_element.text
      log name
      playlist_id = el.xpath("key[text()='Name']").first.next_element.text
      track_ids = el.xpath("key[text()='Playlist Items']").first
      if track_ids
        track_ids = track_ids.next_element.xpath('dict/integer').collect(&:text)
        track_ids.select!{ |track_id| @tracks[track_id] } # some media like movies won't have a track entry, so remove them from the playlist
      else
        progress_step
        # a playlist without track ids is not something we can copy to the device
        next
      end
      @playlists << { name: name, playlist_id: playlist_id, track_ids: track_ids }
      progress_step
    end 
  end

  def generate_playlists
    Dir.mkdir(LOCAL_PLAYLISTS_DIR) unless Dir.exists?(LOCAL_PLAYLISTS_DIR)
    playlists.each do |playlist|
      log playlist[:name]

      playlist_file = "#{LOCAL_PLAYLISTS_DIR}/#{playlist[:name]}.m3u"

      File.delete(playlist_file) if File.exists?(playlist_file)
      File.open(playlist_file, "w") do |file|
        file.puts("#EXTM3U")
        playlist[:track_ids].each do |track_id|
          track = @tracks[track_id]
          playlist_path = track[:device_location][Settings.instance.values[:ftp_path].length..]
          playlist_path.sub!(/^\//, "")
          file.puts(playlist_path)
        end
      end

      playlist[:path] = playlist_file
    end
  end
end
