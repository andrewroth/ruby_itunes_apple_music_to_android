require "fileutils"
require "concurrent"


class Device
  include Logs
  include SetsStatus
  include SetsProgress

  CACHE_KEY_PATH = "./device_cache_key"
  FOLDER_CACHE_PATH = "cache.yml"
  DEVICE_PLAYLISTS_COPY = "./device_playlist_copy"

  attr_accessor :ftp, :folder_cache

  # cache = { path: <ls results> }

  class FolderCache
    include Logs
    include SetsStatus
    include SetsProgress

    Entry = Struct.new(:basename, :type, :mtime, :filesize) do
      def self.new_from_ftp_entry(entry)
        Entry.new(entry.basename.force_encoding("utf-8"), entry.type, entry.mtime, entry.filesize)
      end
      def file?() type == :file; end
      def directory?() type == :dir; end
    end

    def initialize(device)
      @device = device
      if File.exists?(FOLDER_CACHE_PATH)
        cache = YAML.send(YAML.respond_to?(:unsafe_load) ? :unsafe_load : :load, File.read(FOLDER_CACHE_PATH))
        cache = cache.collect do |k, v|
          k.dup.force_encoding("utf-8")
          v.each { |entry| entry.basename.dup.force_encoding("utf-8") }
          [k, v]
        end.to_h
        @cache = Concurrent::Hash.new
        cache.each_pair do |k,v|
          @cache[k] = v
        end
      else
        @cache = Concurrent::Hash.new
      end
    end

    def each(*args, &block)
      @cache.each(*args, &block)
    end

    def empty?
      @cache ||= Concurrent::Hash.new
      log("returning #{@cache.empty?}")
      @cache.empty?
    end

    def [](path)
      path = path.chop if path.end_with?("/")
      @cache ||= Concurrent::Hash.new
      @cache[path]
    end

    def []=(path, val)
      
      path = path.chop if path.end_with?("/")
      path.force_encoding("utf-8")
      val = val.collect { |entry| entry.is_a?(Net::FTP::List::Entry) ? Entry.new_from_ftp_entry(entry) : entry }
      begin
        @cache[path] = val
      rescue RuntimeError
        sleep 0.2
        retry
      end
      write_cache
      val
    end

    def write_cache
      #File.delete(FOLDER_CACHE_PATH) if File.exists?(FOLDER_CACHE_PATH) # not sure why but this seems necessary
      File.write(FOLDER_CACHE_PATH, YAML.dump(@cache))
    end

    def num_threads
      10
    end

    def update_cache(path = nil, recursive = true, thread_id = nil, ftp = nil)
      time = Benchmark.measure do
        update_cache2(path, recursive, thread_id, ftp)
      end
      log("update_cache time: #{time.real}")
    end

    # loop through every directory in music directory and build a big list of files
    def update_cache2(path = nil, recursive = true, thread_id = nil, ftp = nil)

      puts("path: #{path}, recursive: #{recursive}, thread_id: #{thread_id}, ftp.object_id: #{ftp.object_id}")

      # first execution
      if path.nil?
        ftp = FtpWrapper.new
        ftp.connect
        ftp_path = Settings.instance.values[:ftp_path]
        puts("SETUP ftp.object_id #{ftp.object_id}")

        max_progress = ftp.ls_parsed(ftp_path).count{ |entry| entry.directory? || entry.name.end_with?(".m3u") }
        set_progress_max(max_progress + 1)
        
        threads = []
        @@j = 0
        num_threads.times do |thread_id|
          threads << Thread.new {
            ftp2 = FtpWrapper.new
            log("thread #{thread_id} SETUP ftp.object_id #{ftp2.object_id}")
            ftp2.connect
            log("thread #{thread_id} SETUP AFTER ftp.object_id #{ftp2.object_id}")

            update_cache(ftp_path, true, thread_id, ftp2)
          }
        end
        threads.each { |thr| thr.join }

        write_cache
        return
      end

      root_folder = path == Settings.instance.values[:ftp_path] 
      entries = ftp.ls_parsed(path)

      i = 0

      unless recursive
        self[path] = entries
        return
      end

      dirs = entries.find_all(&:directory?)
      dirs.each_with_index do |entry, i|
        next if root_folder && i % num_threads != thread_id

        log("ftp object_id: #{ftp.object_id}, thread_id #{thread_id}, i #{i}")

        sleep 0.2 # make sure other threads and UI get a chance

        if root_folder
          #set_progress_status("Scanning #{entry.name.inspect}", i: i, max: dirs.length)
          set_progress_status("Scanning #{entry.name.inspect}", i: (@@j += 1), max: dirs.length)
        end

        child_path = File.join(path, entry.name)

        # if we've already processed this path with the same mtime, we can assume it's up to take, so skip it
        cached_entry_index = (self[path] || []).index { |child_entry| child_entry.basename == entry.basename }

        log("path: #{path}, child_path: #{child_path}")
        log("found cached entry index #{cached_entry_index}. Compare mtimes #{self[path][cached_entry_index].mtime if cached_entry_index} (cache) <=> #{entry.mtime} (entry)")

        # do the skip if possible
        if cached_entry_index && self[path][cached_entry_index].mtime == entry.mtime
          log("mtime matches for #{child_path}, skipping!")
        else
          update_cache2(child_path, true, thread_id, ftp)
          if cached_entry_index
            log("update entry")
            # find cached index again just in case, it should not be necessary, but just in case. It's quick.
            cached_entry_index = (self[path] || []).index { |child_entry| child_entry.basename == entry.basename }
            self[path][cached_entry_index] = entry
          else
            log("new entry")
            self[path] ||= []
            self[path].unshift(entry)
          end
        end

        if root_folder
          MainUi.instance.progress.value(MainUi.instance.progress.value + 1)
          #progress_step
          log("progress #{MainUi.instance.progress.value}/#{MainUi.instance.progress.maximum}")
        end
      end

      self[path] = entries
    end
  end

  def initialize
    @folder_cache = FolderCache.new(self)
  end

  def ftp
    #FtpWrapper.instance
    @ftp ||= FtpWrapper.new
  end

  def update_folder_cache
    initialize
    @folder_cache.update_cache
  end

  # compare cache_key with cache of ftp_path, if they match cache is valid, otherwise update it
  def scan
    set_main_status("Scanning...")
    if @folder_cache&.empty? || !File.exists?(FOLDER_CACHE_PATH) || !File.exists?(CACHE_KEY_PATH) || File.read(CACHE_KEY_PATH) != cache_key
      log("Difference detected, rebuilding folder cache")
      delete_cache_key
      @folder_cache.update_cache
      update_cache_key
      set_main_status("Scanning Playlists...")
      download_playlists
      progress_step
      progress_complete
    else
      log("No change, continuing on")
    end

    download_playlists if Dir["#{DEVICE_PLAYLISTS_COPY}/*.m3u"].empty?
  end

  # A unique identifier of the root music directory on the device
  # Currently it's simply the ftp ls output of the music directory
  # If this changes, the program will have to rebuild the list of all directories and files
  #
  # That should work ok because any sub file or folder changes will update the root music
  # directory's modified timestamps
  def cache_key
    ftp.connect
    r = ftp.ls(Settings.instance.values[:ftp_path]).join("\n")
    log("key value: #{r.inspect}")
    r
  end

  def update_cache_key
    File.write(CACHE_KEY_PATH, cache_key)
  end

  def delete_cache_key
    File.delete(CACHE_KEY_PATH) if File.exists?(CACHE_KEY_PATH)
  end

  def download_playlists
    ftp.connect
    path = Settings.instance.values[:ftp_path]
    FileUtils.mkdir_p(DEVICE_PLAYLISTS_COPY)

    original_path = Dir.pwd
    Dir.chdir(DEVICE_PLAYLISTS_COPY)

    #Dir.glob("*.m3u").each do |f|
    #  File.delete(f)
    #end

    ftp.ls_parsed(path) do |parsed|
      next unless parsed.name.end_with?(".m3u")
      set_main_status("Scanning Playlists... #{parsed.name}")
      progress_step
      log("Looking for existing playlist: #{parsed.name}, #{File.exists?(parsed.name)}")
      if File.exists?(parsed.name) && File.size(parsed.name) == parsed.filesize
        log("Already have #{parsed.name} locally and size matches, skipping download.")
      else 
        if File.exists?(parsed.name)
          log("No match on file sizes - compare playlist size #{parsed.name} locally #{File.size(parsed.name)} vs device #{parsed.filesize}")
        end
        ftp.download_text(File.join(path, parsed.name))
      end
    end

    Dir.chdir(original_path)
  end

  def update_library_playlists_with_device_info(library)
    library.playlists.each(&:update_with_device_data)
  end

  def copy_to_device(library)
    # set the progress total
    track_ids = library.playlists.find_all(&:checked).collect(&:track_ids).flatten.uniq
    track_ids.reject! { |track_id| library.tracks[track_id].on_device }

    progress_clear
    max_progress = track_ids.count + library.playlists.count(&:checked) + 1
    log("Max progress: #{max_progress}")
    set_progress_max(max_progress)
    
    # verify track file sources exist
    library.verify_tracks(track_ids)
    progress_step

    ftp.connect

    # copy playlists
    library.playlists.each do |playlist|
      next unless playlist.checked

      playlist.copy_to_device(ftp)

      progress_step
    end

    # copy tracks
    track_ids.each_with_index do |track_id, i|
      track = library.tracks[track_id]
      set_progress_status("Copying #{track.location.inspect} -> #{track.device_location.inspect}", i: i + 1, max: track_ids.length)

      #sleep 0.1
      track.copy_to_device(self)

      progress_step
    end

    update_cache_key
    set_main_status("Done Copying, Verifying...")
    scan
    update_library_playlists_with_device_info(library)
    library.match_device_tracks(folder_cache)
    MainUi.instance.populate_playlist_table(device_scanned: true)
    progress_complete
    set_main_status("Done Copying")
  end
end
