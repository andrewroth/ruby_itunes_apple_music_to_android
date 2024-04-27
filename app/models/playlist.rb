class Playlist
  include Logs
  include SetsStatus

  attr_accessor :checked
  attr_reader :name, :playlist_id, :track_ids, :device_tracks_count, :path

  def initialize(name:, playlist_id:, track_ids:, checked:)
    @name = name
    @playlist_id = playlist_id
    @track_ids = track_ids
    @checked = checked
  end

  def generated_path
    File.join(Library::LOCAL_PLAYLISTS_DIR, name + ".m3u")
  end

  def device_copy_path
    File.join(Device::DEVICE_PLAYLISTS_COPY, name + ".m3u")
  end

  def device_path
    File.join(Settings.instance.values[:ftp_path], name + ".m3u")
  end
  
  def update_with_device_data
    if File.exists?(device_copy_path)
      @device_tracks_count = File.read(device_copy_path).split("\n").count{ |line| line != "#EXTM3U" && line != "" }
    end
  end

  def generate(library)
		log("Generating playlist #{name}")

    # this shouldn't be necessary, but sometimes it seemed to be in my testing
		File.delete(generated_path) if File.exists?(generated_path)

		File.open(generated_path, "w") do |file|
			file.puts("#EXTM3U")
			@track_ids.each do |track_id|
				track = library.tracks[track_id]
				file.puts(track.playlist_path)
			end
		end
  end

  def copy_to_device(ftp)
    set_main_status("Copying playlist #{name}, path: #{generated_path}")
    ftp.upload_text(generated_path, device_path)
    FileUtils.cp(generated_path, device_copy_path)
  end
end
