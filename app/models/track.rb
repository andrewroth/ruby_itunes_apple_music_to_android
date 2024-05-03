class Track
  include Logs
  include XmlHelpers
  include SetsStatus

  attr_accessor :on_device, :location, :device_location
  attr_reader :id, :name, :size

  def initialize(id:, name:, size:, location:, music_folder:)
    reset_files_in_directory
    @@disk_file_sizes_to_path ||= {}

    @id = id
    @name = name
    @size = size

    if sub_start = location.index(music_folder)
      device_location = location[(sub_start + music_folder.length)..location.length]
    else
      # for tracks added outside itunes library, grab 3 folders up to handle "Band/Album/Track" format.
      # might want a config option for this in the future
      device_location = File.join(location.split("/").last(3))
    end

    location = unescape_xml(location)
    device_location = unescape_xml(device_location)

    # if device location now starts with Music/ or /Music/, cut that out; same for "mp3" folder
    device_location.sub!(/^\/?Music\//, "")
    device_location.sub!(/^\/?mp3\//, "")

    # try to get a proper file path that will actually exist
    location = strip_url_file_path_starting(location)

    log("track file location: #{location.inspect}, device_location: #{device_location.inspect}")

    byebug if device_location.start_with?("file:")
    device_location = File.join(Settings.instance.values[:ftp_path], device_location)

    @location = location
    @device_location = device_location
  end

  # path to be included in a playlist entry. Android m3u expects no leading /
  def playlist_path
    device_location[Settings.instance.values[:ftp_path].length..].sub(/^\//, "")
  end

  def verify_file
    unless track_file_exists?(@location)
      new_location = find_track_file_by_size(@location, @size)
      @location = new_location if new_location
    end

    if @location.nil? || !track_file_exists?(@location)
      msg = "Error: Track file #{@location.inspect} for #{self.inspect} does not exist, and can't find it by a file size match search."
      set_main_status(msg)
      raise(msg)
    end
  end

  def copy_to_device(device, ftp)
    if on_device
      log("[#{name}] -> No action required, it's already on the device (#{device_location.inspect})")
      return
    end

    log("[#{name}] -> Make directory and copy #{device_location.inspect}")

    # make each parent directory
    base = base_device_path

    File.dirname(device_location[base.length..]).split("/").each do |dir|
      path = File.join(base, dir)
      log("checking cache for #{path}")
      if device.folder_cache[path]
        log("Found cache existing for #{path}, no need to mkdir it")
      else
        log("mkdir #{path.inspect}")
        ftp.mkdir(path)
      end
      base = path
    end

    log("copy #{location.inspect} to #{device_location}")
    ftp.upload_binary(location, device_location)

    # go up the directories until base and update caches
    dir = File.dirname(device_location)
    base = base_device_path
    base.strip! if base.end_with?("/")
    log("base #{base}")
    while dir.length >= base.length
      log("update cache for #{dir.inspect}")
      device.folder_cache.update_cache(dir, false, nil, ftp)
      dir = File.dirname(dir)
    end
  end

  private

  def base_device_path
    Settings.instance.values[:ftp_path]
  end

  def reset_files_in_directory
    @@files_in_directory = {}
  end

  # Used to check that the track paths that are in the iTunes library exist
  def self.glob_dir_files(dir)
    dir.gsub!(/\/$/, "")
    return unless File.directory?(dir)
    @@files_in_directory ||= {}

    # While there could be directories in here also, not just files, it's fine to just throw everything in
    # because it saves a disk hit to check if the path is a file or directory. This is the tradeoff for
    # quickly checking if a file exists on disk.
    @@files_in_directory.merge!(Dir.glob("#{dir}/**/*").collect{ |p| [p, true] }.to_h)
  end

  # Used to match tracks by size. Builds a hash of file sizes to hash for a directory
  def disk_file_sizes_to_path(dir, extension)
    log("enter disk_file_sizes_to_path(dir: #{dir.inspect}, extension: #{extension}")
    return {} unless File.directory?(dir)

    dir = dir.chop if dir.end_with?("/")

    # store results in instance variable to avoid having to compute file sizes again if the same directories are hit
    @@disk_file_sizes_to_path ||= {}

    glob_path = "#{dir}/**/*.#{extension}"
    log("globbing #{glob_path}")

    Dir.glob(glob_path).each do |path|
      next if File.directory?(path)

      log("@@disk_file_sizes_to_path[#{File.size(path)}] = #{path.inspect}")
      @@disk_file_sizes_to_path[File.size(path)] = path
    end

    @@disk_file_sizes_to_path
  end

  # If a file can't be found on disk, I think the best approach is to just look for the file by exact size match,
  # going up directories from the most nested first. The more nested the path the less files to look through to
  # match by size, but the special character might be in the nested directory.
  def find_track_file_by_size(track_path, track_size)
    log("enter find_track_file_by_size(track_path: #{track_path.inspect}, track_size: #{track_size})")
    base = File.dirname(track_path)
    extension = track_path.split(".").last

    # look for a match already, maybe from a previous file size scan
    if path = @@disk_file_sizes_to_path[track_size]
      log("found path for #{track_path}: #{path}")
      return path
    end

    # look in current path dir then go up one dir, keep trying unil music_folder
    split_base = base.split("/")
    i = 0
    while split_base.any?
      log("search look, split_base: #{split_base.inspect}")

      if ((i += 1) == 3) && "#{split_base.join("/")}/".length < (fp = MainUi.instance.library.music_folder_path).length
        log("Giving up search because searched at least 3 directories up (if possible), and #{split_base.join("/").inspect} hit under music folder #{fp.inspect}")
        break
      end

      disk_file_sizes_to_path(split_base.join("/"), extension)
      if path = @@disk_file_sizes_to_path[track_size]
        log("found path for #{track_path}: #{path}")
        return path
      end

      split_base.pop
    end

    nil
  end

  def track_file_exists?(location)
    return true if @@files_in_directory[location]

    original_location = location

    3.times do
      if File.directory?(parent = File.dirname(location))
        Track.glob_dir_files(parent)
        return true if @@files_in_directory[original_location]
        location = parent
      end
    end

    return true if @@files_in_directory[original_location]

    File.exist?(original_location)
  end
end
