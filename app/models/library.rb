require "nokogiri"
require "cgi"
require "benchmark"

class Library
  include Logs
  include SetsProgress
  include SetsStatus
  include XmlHelpers

  LOCAL_PLAYLISTS_DIR = "./playlists_from_library"

  attr_accessor :tracks, :playlists, :tracks_by_size, :music_folder

  def initialize(xml_path = "Library.xml")
    time = Benchmark.measure do
      @disk_file_sizes_to_path = {}
      log("Loading #{xml_path}...")
      @doc = File.open(xml_path) { |f| Nokogiri::XML(f) };
      log("Done")
      @music_folder = @doc.xpath('/plist/dict/key[text()="Music Folder"]').first.next_element.text
      @music_folder_path = strip_url_file_path_starting(unescape_xml(@music_folder))
      glob_dir_files(@music_folder_path)
      set_progress_total
      load_tracks
      #verify_tracks
      load_playlists
      log("progress #{MainUi.instance.progress.value}/#{MainUi.instance.progress.maximum}")
      progress_complete
    end
    puts time.real
  end

  def verify_tracks(track_ids = nil)
    track_ids ||= @tracks.keys

    track_ids.each do |track_id|
      track = @tracks[track_id]
      #progress_step

      track.verify_file
    end
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

        @tracks[track_id] = Track.new(id: track_id, name: name, size: size, location: location, music_folder: @music_folder)

        progress_step
      end
    end 

    @tracks_by_size = @tracks.values.group_by(&:size)
  end

  def match_device_tracks(device_cache)
    @tracks.each_pair do |track_id, track|
      track.on_device = false
    end

    device_cache.each do |path, entries|
      entries.each do |entry|
        next unless entry.file?

        full_path = File.join(path, entry.basename)

        log("Search for #{entry.filesize} (#{full_path})")
        if tracks = @tracks_by_size[entry.filesize]
          if tracks.length == 1
            log("   -> #{tracks}")
            @tracks[tracks.first[:id]].device_location = full_path
            @tracks[tracks.first[:id]].on_device = true
          elsif tracks.length > 1
            log("MULTIPLE MATCHES FOR #{File.join(path, entry.basename)}")
            track = tracks.detect{ |t| File.basename(t.location).gsub("%20", "") }

            if track
              log("Found match for #{full_path}: #{tracks}")
              @tracks[track[:id]].device_location = full_path
              @tracks[track[:id]].on_device = true
            else
              raise("Multiple maches for #{entry}")
              # byebug
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
      @playlists << Playlist.new(name: name, playlist_id: playlist_id, track_ids: track_ids, checked: (Settings.instance.values[:checked_playlist_ids] || []).include?(playlist_id))
      progress_step
    end 
  end

  def generate_playlists
    set_main_status("Generating playlists...")
    Dir.mkdir(LOCAL_PLAYLISTS_DIR) unless Dir.exists?(LOCAL_PLAYLISTS_DIR)

    playlists.each do |playlist|
      # TODO here below can be moved to playlist class
      log playlist.name

      playlist_file = "#{LOCAL_PLAYLISTS_DIR}/#{playlist.name}.m3u"

      File.delete(playlist_file) if File.exists?(playlist_file)
      File.open(playlist_file, "w") do |file|
        file.puts("#EXTM3U")
        playlist.track_ids.each do |track_id|
          track = @tracks[track_id]
          file.puts(track.playlist_path)
        end
      end

      playlist[:path] = playlist_file
    end
    set_main_status("")
  end

  private

  def set_progress_total
    tracks_count = @doc.xpath('/plist/dict/key[text()="Tracks"]').first.next_element.search("> key").count
    playlists_count = @doc.xpath('/plist/dict/key[text()="Playlists"]').first.next_element.xpath("dict").count
    set_progress_max(tracks_count + playlists_count)
  end

end
