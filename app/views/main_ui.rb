require "tk"
require "tkextlib/tile"
require "tkextlib/iwidgets/scrolledtext"

class MainUi
  include Singleton
  include HasStatus
  include Logs

  attr_accessor :ftp_path, :device, :playlist_table_var, :library, :select_ftp_path_window, :progress, :copy_button, :status_label, :scan_device_button, :scan_note, :log_text

  def window_name
    "main window"
  end

  def start
    build_ui
    bring_to_front
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

    Tk.mainloop
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
    load_library if ::Settings.instance.values[:library_path] && File.exists?(::Settings.instance.values[:library_path])
  end

  def load_library
    Thread.new {
      #sleep 0.5
      set_status("Loading library...")
      @library = Library.new(::Settings.instance.values[:library_path])
      set_status("")
      populate_playlist_table
      @scan_device_button.state("normal")
    }
  end

  def populate_playlist_table(device_scanned: false)
    return unless @library && @playlist_table_var

    if @table.rows != @library.playlists.count + 1
      @table.configure(rows: @library.playlists.count + 1)
    end

    @library.playlists.each_with_index do |playlist, i|
      set_status("Building table row for #{playlist.name}")
      @playlist_table_var[i,1] = playlist.name
      @playlist_table_var[i,2] = playlist.track_ids.length
      if device_scanned
        @playlist_table_var[i,3] = playlist.device_tracks_count.to_i
        @playlist_table_var[i,4] = playlist.track_ids.count{ |track_id| !@library.tracks[track_id].on_device }
      end

      playlist.checked ? check_table_row(i) : uncheck_table_row(i)
    end
    set_status("")
  end

  def save_checked_rows
    @checked_playlist_ids = @library.playlists.find_all(&:checked).collect(&:playlist_id)
    save_settings
  end

  def check_table_row(row)
    set_table_row_checked(row, true)
  end

  def uncheck_table_row(row)
    set_table_row_checked(row, false)
  end

  def set_table_row_checked(row, checked)
    prefix = checked ? "" : "not_"
    @table.tag_cell("#{prefix}checked", "#{row},0")
    @table.tag_cell("left-#{prefix}checked", "#{row},1")
    @table.tag_cell("#{prefix}checked", "#{row},2")
    @table.tag_cell("#{prefix}checked", "#{row},3")
    @table.tag_cell("#{prefix}checked", "#{row},4")
    pl = @library.playlists.detect{ |pl| pl.name == @playlist_table_var["#{row},1"] }
    raise("can't find pl for row #{row}") unless pl
    pl.checked = checked
    @playlist_table_var[row,0] = ""
    save_checked_rows
  end

  class SettingsEntry < Ttk::Entry
    def initialize(frame, instance, key)
      super(frame)
      insert 0, Settings.instance.values[key]
      grid_configure sticky: "w"
      validate "key"
      validatecommand [proc { Thread.new { sleep 0.5; instance.save_settings } }] # need to wait half a second for the key to enter the field
    end
  end

  def scroll_scale
    RUBY_PLATFORM["darwin"] ? 1 : 120
  end

  # I'm not super happy with this method. The UI building is a bit hodge-podge pulled from various examples online and built with a focus on 
  # just working. TODO would be to at least build and pack the UI with consistent methods, ex. within a do block on the element or after.
  def build_ui
    instance = self
    settings = Settings.instance.values

    root = TkRoot.new
    root.title = "FTP iTunes/Apple Music to Android Copy"
    root.geometry("1000x800")

    root.bind_all("MouseWheel", proc { |event|
      #puts("Mouse event #{event.inspect} #{-event.wheel_delta/scroll_scale} #{$scroll&.get}");
      begin
        if @notebook.selected != @frame_log
          $scroll_target&.yview("scroll", -event.wheel_delta/scroll_scale, "units")
        end
      rescue Exception => e
        msg = "Error: #{e.class.name} #{e.to_s}"
        log(msg)
        instance.log_trace(e)
      end

    }) # $scroll&.set(120,140); $scroll&.assign})

=begin
    @status_label = Ttk::Label.new(root) {
      wraplength 990
      justify :left
      text Tk::UTF8_String.new(MainUi.intro_text)
      #width 100
    }.pack(side: :top, fill: :x)
=end

=begin
    # this one (or similar to it) was causing some crashes on a macbook air
    @status_label = Ttk::Label.new(frame) {
      justify :left
      wraplength 980
      text Tk::UTF8_String.new("Status: ")
      grid column: 0, row: 2, columnspan: 2
      grid_configure sticky: "ews", padx: [20, 20]
    }
=end

    @notebook = Tk::Tile::Notebook.new(root) do
      height 400
      #place('height' => 675, 'width' => 1000, 'x' => 0, 'y' => 0)
      pack(side: :top, fill: :both, expand: true)
    end

    frame_main = TkFrame.new(@notebook)
    @frame_log = frame_log = TkFrame.new(@notebook)
    frame_about = TkFrame.new(@notebook)

    @notebook.add frame_main, text: "Main"

    @notebook.add frame_log, text: "Log"
    #@log_text = TkText.new(frame_log) do
    @log_text = Tk::Iwidgets::Scrolledtext.new(frame_log) do
      borderwidth 1
      #font TkFont.new('times 8')
      pack(side: :top, fill: :both, expand: true)
    end

    @notebook.add frame_about, text: "About"
    Ttk::Label.new(frame_about) {
      wraplength 900
      #justify :left
      text Tk::UTF8_String.new(MainUi.intro_text)
      #width 100
    }.pack(pady: 10) #(side: :top, fill: :both)


    base_frame = frame_main

    Ttk::Frame.new(root) do |frame|
      sep = Ttk::Separator.new(frame)
      Tk.grid(sep, columnspan: 4, row: 0, sticky: "ew", pady: 2)

      instance.status_label = Ttk::Label.new(frame) {
        wraplength 990
        justify :left
        text Tk::UTF8_String.new(" ")
        #width 100
      }
      Tk.grid(instance.status_label, columnspan: 4, row: 1, sticky: "ew", pady: 2, padx: [20, 20])

      instance.progress = Ttk::Progressbar.new(frame, mode: :determinate) {
        grid column: 0, row: 3, columnspan: 2
        grid_configure sticky: "ews", padx: [20, 20]
      }
      Tk.grid(instance.progress, columnspan: 4, row: 2, sticky: "ew", pady: 2)

      sep = Ttk::Separator.new(frame)
      Tk.grid(sep, columnspan: 4, row: 3, sticky: "ew", pady: 2)

      TkGrid('x', Ttk::Button.new(frame, text: "Quit", compound: :left, command: -> { root.destroy; exit(0) }), padx: 4, pady: 4, row: 4)
      grid_columnconfigure(0, weight: 1)

      pack(side: :bottom, fill: :x)
    end

    frame = TkFrame.new(base_frame).pack(side: :top, fill: :x, expand: false)
    #frame.background "red"

    Ttk::Label.new(frame) {
      justify :left
      text Tk::UTF8_String.new("library xml file path:")
      grid column: 0, row: 0
      grid_configure sticky: "w"
    }

    @library_path = SettingsEntry.new(frame, instance, :library_path) {
      grid column: 1, row: 0
    }

    Ttk::Label.new(frame) {
      justify :left
      text Tk::UTF8_String.new("FTP Server IP:")
      grid column: 2, row: 0
      grid_configure sticky: "w", padx: [20, 0]
    }

    @ftp_ip = SettingsEntry.new(frame, instance, :ftp_ip) {
      grid column: 3, row: 0
    }

    Ttk::Label.new(frame) {
      justify :left
      text Tk::UTF8_String.new("FTP Server Port:")
      grid column: 4, row: 0
      grid_configure sticky: "w", padx: [20, 0]
    }

    @ftp_port = Ttk::Entry.new(frame) {
      insert 0, settings[:ftp_port]
      insert 0, ""
      grid column: 5, row: 0
      grid_configure sticky: "w"
    }

    Ttk::Label.new(frame) {
      justify :left
      text Tk::UTF8_String.new("FTP Music Directory:")
      grid column: 0, row: 1
      grid_configure sticky: "w"
    }

    $ftp_path = @ftp_path = SettingsEntry.new(frame, instance, :ftp_path) {
      grid column: 1, row: 1
    }

    Ttk::Label.new(frame) {
      justify :left
      text Tk::UTF8_String.new("FTP Username:")
      grid column: 2, row: 1
      grid_configure sticky: "w", padx: [20, 0]
    }

    @ftp_username = SettingsEntry.new(frame, instance, :ftp_username) {
      grid column: 3, row: 1
    }

    Ttk::Label.new(frame) {
      justify :left
      text Tk::UTF8_String.new("FTP Password:")
      grid column: 4, row: 1
      grid_configure sticky: "w", padx: [20, 0]
    }

    @ftp_password = SettingsEntry.new(frame, instance, :ftp_password) {
      grid column: 5, row: 1
    }

    @select_ftp_path_window = nil
    Ttk::Button.new(frame) {
      text "Select Path"
      grid_configure sticky: "w"

      command proc {
        begin
          @select_ftp_path_window.destroy
        rescue
        end
        @select_ftp_path_window = SelectMusicDirectoryUi.new
      }

      grid column: 1, row: 2
    }

    build_table(base_frame)

    frame = TkFrame.new(base_frame).pack(side: :bottom, fill: :x, expand: false)
		#frame.background "blue"

    frame_scan = TkFrame.new(frame)
		#frame_scan.background "green"
		frame_scan.grid column: 0, row: 0
		frame_scan.grid_configure sticky: "ws"

    @scan_device_button = Ttk::Button.new(frame_scan) {
      state "disabled"
      text "Scan Device"
      command proc {
        Thread.new {
          begin
            msg = "Scanning..."
            instance.scan_device_button.state("disabled")
            instance.copy_button.state("disabled")
            MainUi.instance.set_status(msg)
            MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
            instance.device.scan
            instance.device.update_library_playlists_with_device_info(instance.library)
            instance.library.match_device_tracks(instance.device.folder_cache)
            instance.populate_playlist_table(device_scanned: true)
            msg = "Scan complete, ready to copy."
            instance.scan_note.configure(text: Tk::UTF8_String.new(""))
            MainUi.instance.set_status(msg)
            MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
            instance.scan_device_button.state("normal")
            instance.copy_button.state("normal")
          rescue Net::OpenTimeout => e
            # FtpWrapper should already have set an appropriate status
          rescue Exception => e
            instance.log_trace(e)
            msg = "Error: #{e.class.name} #{e.to_s}"
            MainUi.instance.set_status(msg)
            MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
            raise
          end
        }
      }
      grid column: 0, row: 0
      grid_configure sticky: "ws", padx: [20, 0]
    }

    @scan_note = Ttk::Label.new(frame_scan) {
      justify :left
      wraplength 800
      text Tk::UTF8_String.new("Note: You must scan the device before starting the copy.")
      grid column: 1, row: 0
      grid_configure sticky: "w", padx: [20, 0]
    }

    @copy_button = Ttk::Button.new(frame) {
      state "disabled"
      text "Copy To Device"
      command proc {
        Thread.new {
          msg = "Copying..."
          instance.scan_device_button.state("disabled")
          instance.copy_button.state("disabled")
          MainUi.instance.set_status(msg)
          MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
          instance.log("Copy to Device")
          instance.library.generate_playlists
          instance.device.copy_to_device(instance.library)
          instance.scan_device_button.state("enabled")
          instance.copy_button.state("enabled")
        }
      }
      grid column: 0, row: 1
      grid_configure sticky: "ws", padx: [20, 0]
    }

=begin
    @status_label = Ttk::Label.new(frame) {
      justify :left
      wraplength 980
      text Tk::UTF8_String.new("Status: ")
      grid column: 0, row: 2, columnspan: 2
      grid_configure sticky: "ews", padx: [20, 20]
    }
=end

		frame.grid_columnconfigure(0, weight: 1)

  end

  def build_table(root)
    frame = TkFrame.new(root).pack(side: :top, fill: :both, expand: true)
		#frame.background "yellow"

    #byebug
    @playlist_table_var = tab = TkVariable.new_hash
    rows = 0
    cols = 5

    scroll = nil
    params = { rows: rows + 1, cols: cols, variable: tab, titlerows: 1, titlecols: 0,
               roworigin: -1, colorigin: 0, #colwidth: 4, width: 8, height: 8,
               #colstretchmode: "all",
               maxheight: "300",
               maxwidth: "1000", cursor: 'top_left_arrow', borderwidth: 2,
               flashmode: false, state: :disabled
    }
    $scroll_target = @table = table = Tk::TkTable.new(frame, params) {
      pack('side' => 'left', 'fill' => 'both', 'expand' => 0)
    }
    #table.set_width([[0,8],[1,92],[2,15],[3, 15],[4, 15],[5,15]])
    table.set_width([[0,-100],[1,-475],[2,-100],[3, -100],[4, -100],[5,-100]])

    $scroll = scroll = table.yscrollbar(TkScrollbar.new(frame) {
      pack('side' => 'left', 'fill' => 'y', 'expand' => 0)
    })
    table.lower

    not_checked = { relief: :ridge }
    checked = { relief: :sunken, bg: "#AAAAAA" } # "sunked": must be flat, groove, raised, ridge, solid, or sunken
    left = { anchor: "w", justify: :left }
    table.tag_configure("left-not_checked", not_checked.merge(left))
    table.tag_configure("left-checked", checked.merge(left))
    table.tag_configure("not_checked", not_checked)
    table.tag_configure("checked", checked)

    # clean up if mouse leaves the widget
    table.bind('Leave', proc{|w| w.selection_clear_all}, '%W')

    instance = self

    # highlight the cell under the mouse
    table.bind('Motion', proc{|w, x, y|
      Tk.callback_break if w.selection_include?(TkComm._at(x,y))
      w.selection_clear_all
      #puts "x,y #{x},#{y} #{TkComm._at(x,y).inspect}"
      #w.selection_set(TkComm._at(x,y))
      #puts "#{w}"
      #puts "#{w.width_list}"
      #w.selection_set(TkComm._at(30,y), TkComm._at(460,y))
      w.selection_set(TkComm._at(5,y), TkComm._at(w.width_list.collect{ |row, width| width }.sum.abs, y))
      Tk.callback_break
      ## "break" prevents the call to tkTableCheckBorder
    }, '%W %x %y')

    # mousebutton 1 toggles the value of the cell
    # use of "selection includes" would work here
    table.bind('1', proc{|w, x, y|
      #rc = w.curselection[0]
      rc = w.index(TkComm._at(x,y))
      #puts("rc: #{rc.inspect}, tab[rc]: #{tab[rc]}")
      #select_path_list_path("#{@ftp_path.text}#{tab[rc]}/")
      
      row = rc.split(",")[0]
      return if row == "-1"
      idx = "#{row},1"
      #puts idx
      #puts tab[idx]

      checked = w.tag_include?("left-checked", idx)
      checked ? instance.uncheck_table_row(row) : instance.check_table_row(row)
    }, '%W %x %y')

    # initialize the array, titles, and celltags
    tab[-1, 0] = "Copy"
    tab[-1, 1] = "Name"
    tab[-1, 2] = "# Tracks"
    tab[-1, 3] = "Device # Tracks"
    tab[-1, 4] = "Tracks To Copy"

    0.step(rows) {|i|
      0.step(cols){|j|
        #puts("tab #{i},#{j}")
        #tab[i,j] = "#{i},#{j}"
        table.tag_cell('OFF', "#{i},#{j}")
      }
    }
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
