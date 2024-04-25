class Playlist
  attr_writer :checked
  attr_reader :name, :playlist_id, :track_ids, :device_tracks_count

  def initialize(name:, playlist_id: track_ids:, checked:)
    @name = name
    @playlist_id = playlist_id
    @track_ids = track_ids
    @checked = checked
  end

  def filename
    File.join(Library::LOCAL_PLAYLISTS_DIR, playlist.name + ".m3u")
  end

  def local_copy_filename
    File.join(DEVICE_PLAYLISTS_COPY, playlist.name + ".m3u")
  end

  def update_with_device_data
    playlist_filename = File.join(DEVICE_PLAYLISTS_COPY, playlist.name + ".m3u")
    if File.exists?(local_copy_filename)
      @device_tracks_count = File.read(playlist_filename).split("\n").count{ |line| line != "#EXTM3U" && line != "" }
    end
  end
end
