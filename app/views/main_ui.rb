class MainUi
  include Singleton
  include HasStatus
  include Logs

  attr_accessor :ftp_path, :device, :playlist_table_var, :library, :select_ftp_path_window, :progress, :copy_button, :status_label, :scan_device_button, :scan_note, :log_text, :notebook

  def window_name
    "main window"
  end

  def start
    #bring_to_front
    load_settings
    check_load_library

    Thread.new do
      begin
        @device = Device.new
      rescue Exception => e
        msg = "Error instantiating device: #{e.class.name} #{e.to_s}"
        set_status(msg)
        log.log_trace(e)
        raise
      end
    end
  end

  def message(val)
    if val.is_a?(Hash) && val["data"] && self.respond_to?(val["data"].to_sym)
      self.send(val["data"])
      return
    end

    if val["data"] == "table-click" && val["playlist_id"]
      pl = @library.playlists.detect{ |pl| pl.playlist_id == val["playlist_id"] }
      if pl
        pl.checked = !pl.checked
        populate_playlist_table(device_scanned: @device_scanned)
        save_checked_rows
      end
    end
  end

  class SettingsEntry
    def initialize(id, settings)
      @id = id
      self.value = settings[id] if settings
    end

    def value=(val)
      WebServer.instance.driver.execute_script(%|$("##{@id}").val("#{val}")|)
    end

    def get
      cmd = %|$("##{@id}").val()|
      #puts cmd
      r = WebServer.instance.driver.execute_script(%|return #{cmd}|)
      #puts r
      r
    end
  end

  def load_settings
    settings = ::Settings.instance.values

    @library_path = SettingsEntry.new(:library_path, settings)
    @ftp_ip = SettingsEntry.new(:ftp_ip, settings)
    @ftp_port = SettingsEntry.new(:ftp_port, settings)
    @ftp_username = SettingsEntry.new(:ftp_username, settings)
    @ftp_password = SettingsEntry.new(:ftp_password, settings)
    @ftp_path = SettingsEntry.new(:ftp_path, settings)
  end

  def save_settings
    log "save here"

    library_path_before = ::Settings.instance.values[:library_path]

    ::Settings.instance.values = {
      library_path: @library_path.get,
      ftp_ip: @ftp_ip.get,
      ftp_port: @ftp_port.get,
      ftp_username: @ftp_username.get,
      ftp_password: @ftp_password.get,
      ftp_path: @ftp_path.get,
      checked_playlist_ids: @checked_playlist_ids
    }

    check_load_library if library_path_before != @library_path.get
  end

  def check_load_library
    log("check_load_library #{::Settings.instance.values[:library_path]}")
    load_library if ::Settings.instance.values[:library_path] && File.exist?(::Settings.instance.values[:library_path])
  end

  def load_library
    Thread.new {
      #sleep 0.5
      set_status("Loading library...")
      @library = Library.new(::Settings.instance.values[:library_path])
      set_status("")
      populate_playlist_table
      WebServer.exec(%|$("#scan").removeAttr("disabled")|)
    }
  end

  def populate_playlist_table(device_scanned: false)
    return unless @library

    @library.playlists.each_with_index do |playlist, i|
      set_status("Building table row for #{playlist.name}")
      tr = %|<tr data-id='#{playlist.playlist_id}' class='#{playlist.checked ? "table-secondary" : ""}'>|
      tr += "<td>#{playlist.checked ? "COPY" : ""}</td>"
      tr += "<td>#{WebServer.h(playlist.name)}</td>"
      tr += "<td>#{WebServer.h(playlist.track_ids.length)}</td>"
      if device_scanned
        tr += "<td>#{WebServer.h(playlist.device_tracks_count.to_i)}</td>"
        on_device = playlist.track_ids.count{ |track_id| !@library.tracks[track_id].on_device }
        tr += "<td>#{WebServer.h(on_device)}</td>"
      else
        tr += "<td></td><td></td>"
      end
      cmd = %|tr = "#{tr}"; r = $("#playlists tbody tr[data-id=#{playlist.playlist_id}]"); r.length == 1 ? r.replaceWith(tr) : $("#playlists tbody").append(tr);|
      #puts cmd
      WebServer.exec(cmd)
    end
    WebServer.exec("reset_table_listeners()")
    set_status("")
  end

  def save_checked_rows
    @checked_playlist_ids = @library.playlists.find_all(&:checked).collect(&:playlist_id)
    save_settings
  end

  def bring_to_front
    Thread.new {
      sleep 0.5
      begin
        system(%|/usr/bin/osascript -e 'tell app "Finder" to set frontmost of process "ruby" to true'|).inspect
      rescue
      end
    }
  end

  def scan
    Thread.new {
      begin
        msg = "Scanning..."
        #WebServer.exec(%|$("#scan").removeAttr("disabled")|)
        WebServer.exec(%|$("#scan").attr("disabled", "true")|)
        WebServer.exec(%|$("#copy").attr("disabled", "true")|)
        set_status(msg)
        #MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
        device.scan
        device.update_library_playlists_with_device_info(library)
        library.match_device_tracks(device.folder_cache)
        @device_scanned = true
        populate_playlist_table(device_scanned: true)
        msg = "Scan complete, ready to copy."
        #instance.scan_note.configure(text: Tk::UTF8_String.new(""))
        set_status(msg)
        #MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
        WebServer.exec(%|$("#scan").removeAttr("disabled")|)
        WebServer.exec(%|$("#copy").removeAttr("disabled")|)
      rescue Net::OpenTimeout => e
        # FtpWrapper should already have set an appropriate status
      rescue Exception => e
        log_trace(e)
        msg = "Error: #{e.class.name} #{e.to_s}"
        set_status(msg)
        #MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
        raise
      ensure
        WebServer.exec(%|$("#scan").removeAttr("disabled")|)
      end
    }
  end

  def copy
    msg = "Copying..."
    WebServer.exec(%|$("#scan").attr("disabled", "true")|)
    WebServer.exec(%|$("#copy").attr("disabled", "true")|)
    MainUi.instance.set_status(msg)
    MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
    log("Copy to Device")
    library.generate_playlists
    device.copy_to_device(library)
    WebServer.exec(%|$("#scan").removeAttr("disabled")|)
    WebServer.exec(%|$("#copy").removeAttr("disabled")|)
  end

  def self.intro_text
    <<~EOS
      Copyright Andrew Roth 2024, andrewroth@gmail.com, released under GPL license

      http://github.com/andrewroth/ruby_itunes_apple_music_to_android

      This program is for copying iTunes or Apple Music songs and playlists to an android \
      phone or tablet. Before starting, you will have to go in to Tunes or \
      Apple Music and choose File > Library > Export Library. Save the file to the same \
      directory as this program.

      FTP is used to transfer the playlists and music files to your device. \
      You'll have to run an FTP server on your device. I suggest "File Manager Plus", it's \
      free and works well. Use "Access from network" in its home screen to run the FTP server. \
      The url in File Manager Plus is in the format ftp://<ip>:<port>.
    EOS
  end
end
