require "nokogiri"
require "cgi"
require "benchmark"

class Library
  include Logs
  include SetsProgress
  include SetsStatus

  LOCAL_PLAYLISTS_DIR = "./playlists_from_library"

  attr_accessor :tracks, :playlists, :tracks_by_size, :music_folder

  def initialize(xml_path = "Library.xml")
    time = Benchmark.measure do
      @disk_file_sizes_to_path = {}
      log("Loading #{xml_path}...")
      @doc = File.open(xml_path) { |f| Nokogiri::XML(f) };
      log("Done")
      @music_folder = @doc.xpath('/plist/dict/key[text()="Music Folder"]').first.next_element.text
      @music_folder_path = unescape_xml(strip_url_file_path_starting(@music_folder))
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

  def glob_dir_files(dir)
    dir.gsub!(/\/$/, "")
    @files_in_music_folder ||= {}
    @files_in_music_folder.merge!(Dir.glob("#{dir}/**/*").collect{ |p| [p, true] }.to_h)
  end

  def set_progress_total
    tracks_count = @doc.xpath('/plist/dict/key[text()="Tracks"]').first.next_element.search("> key").count
    playlists_count = @doc.xpath('/plist/dict/key[text()="Playlists"]').first.next_element.xpath("dict").count
    set_progress_max(tracks_count + playlists_count)
  end

  def unescape_xml(s)
    # https://stackoverflow.com/questions/1091945/what-characters-do-i-need-to-escape-in-xml-documents/17448222#17448222
    s.gsub("&#60;", "<")
      .gsub("&#62;", ">")
      .gsub("&#34;", "\"")
      .gsub("&#38;", "&")
      .gsub("&#39;", "'")
    # ex "Crumba%CC%88cher" -> "Crumbächer"; CC and 88 are hex bytes of a UTF-8 string encoding
      .gsub(/%([0-9,A-F]{2})/) { |s| [$1.to_i(16)].pack("c*").force_encoding("UTF-8") }
  end

  # store results in instance variable to avoid having to compute file sizes again if the same directories are hit
  def disk_file_sizes_to_path(dir, extension)
    log("enter disk_file_sizes_to_path(dir: #{dir.inspect}, extension: #{extension}")
    return {} unless File.directory?(dir)

    dir = dir.chop if dir.end_with?("/")

    @disk_file_sizes_to_path ||= {}

    glob_path = "#{dir}/**/*.#{extension}"
    log("globbing #{glob_path}")

    Dir.glob(glob_path).each do |path|
      unless File.directory?(path)
        log("@disk_file_sizes_to_path[#{File.size(path)}] = #{path.inspect}")
        @disk_file_sizes_to_path[File.size(path)] = path
      end
    end

    @disk_file_sizes_to_path
  end

  # Some of the encoding iTunes does for special characters is very odd. Since we know the file sizes, I think the
  # best approach is to just look for the file by exact size match, going up directories from the most nested first.
  # The more nested the path the less files to look through to match by size, but the special character might be in the
  # nested directory.
  def find_track_file_by_size(track_path, track_size)
    log("enter find_track_file_by_size(track_path: #{track_path.inspect}, track_size: #{track_size})")
    base = File.dirname(track_path)
    extension = track_path.split(".").last

    # look for a match already, maybe from a previous file size scan
    if path = @disk_file_sizes_to_path[track_size]
      log("found path for #{track_path}: #{path}") 
      return path
    end

    # look in current path dir then go up one dir, keep trying unil music_folder
    split_base = base.split("/")
    i = 0
    while split_base.any?
      log("search look, split_base: #{split_base.inspect}")

      if ((i += 1) == 3) && "#{split_base.join("/")}/".length < @music_folder_path.length
        log("Giving up search because searched at least 3 directories up (if possible), and #{split_base.join("/").inspect} hit under music folder #{@music_folder_path.inspect}")
        break
      end

      disk_file_sizes_to_path(split_base.join("/"), extension)
      if path = @disk_file_sizes_to_path[track_size]
        log("found path for #{track_path}: #{path}") 
        return path
      end

      split_base.pop
    end

    nil
  end

  # "file:///Users/andrew/Music/iTunes/iTunes%20Media/" -> "//Users/andrew/Music/iTunes/iTunes%20Media/"
  def strip_url_file_path_starting(s)
    s.gsub(/^file:\/\/(localhost\/)?/, "")
  end

  def track_file_exists?(location)
    return true if @files_in_music_folder[location]

    original_location = location

    3.times do
      if File.directory?(parent = File.dirname(location))
        glob_dir_files(parent)
        return true if @files_in_music_folder[original_location]
        location = parent
      end
    end

    return true if @files_in_music_folder[original_location]

    File.exists?(original_location)
  end

  def verify_tracks(track_ids = nil)
    track_ids ||= @tracks.keys

    track_ids.each do |track_id|
      track = @tracks[track_id]
      #progress_step

      location = track[:location]
      size = track[:size]

      unless track_file_exists?(location)
        new_location = find_track_file_by_size(location, size) 
        location = new_location if new_location
      end

      if location.nil? || !track_file_exists?(location)
        msg = "Error: Track file #{location.inspect} does not exist, and can't find it by a file size match search."
        set_main_status(msg)
        raise(msg)
      end
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

        if sub_start = location.index(@music_folder)
          device_location = location[(sub_start + @music_folder.length)..location.length]
        else
          #device_location = File.join(File.dirname(location).split("/").last(3))
          device_location = File.join(location.split("/").last(3))
        end

        #location = CGI.unescape(location)
        #device_location = CGI.unescape(device_location)
        location = unescape_xml(location)
        device_location = unescape_xml(device_location)

        # if device location now starts with Music/ or /Music/, cut that out
        device_location.sub!(/^\/?Music\//, "")

        # try to get a proper file path that will actually exist
        location = strip_url_file_path_starting(location)

        log("track file location: #{location.inspect}, device_location: #{device_location.inspect}")

        byebug if device_location.start_with?("file:")
        device_location = File.join(Settings.instance.values[:ftp_path], device_location)

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

        #begin
          #full_path = File.join(path.force_encoding("utf-8"), entry.basename.force_encoding("utf-8"))
          full_path = File.join(path, entry.basename)
        #rescue
          #byebug
        #end

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
    set_main_status("Generating playlists...")
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
    set_main_status("")
  end
end
