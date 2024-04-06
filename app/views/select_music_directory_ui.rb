class SelectMusicDirectoryUi < TkToplevel
  UP_ONE_DIR_NAME = ".."

  attr_accessor :select_ftp_path_ftp

  def initialize
    super
    build_ui
    puts("DONE BUILD UI")
    connect_ftp
  end

  def build_ui
    instance = self

    root = self
    root.title = "Select FTP Path"
    root.geometry("800x600")

    TkFrame.new(root) do |frame|
      sep = Ttk::Separator.new(frame)
      Tk.grid(sep, columnspan: 4, row: 0, sticky: "ew", pady: 2)
      TkGrid('x', Ttk::Button.new(frame, text: "Cancel", compound: :left, command: -> { instance.destroy }), padx: 4, pady: 4)
      grid_columnconfigure(0, weight: 1)
      pack(side: :bottom, fill: :x)
    end

    frame = TkFrame.new(root)
    TkGrid(Ttk::Button.new(frame, text: "Select Folder", command: -> { MainUi.instance.ftp_path.insert(0, @ftp_path.text); MainUi.instance.save_settings; instance.destroy;  }), padx: 4, pady: 4)
    frame.grid_columnconfigure(0, weight: 1)
    frame.pack(side: :bottom, fill: :x)

    frame = TkFrame.new(root)
    sep = Ttk::Separator.new(frame)
    @status_text_label = Ttk::Label.new(frame) {
      wraplength 600
      justify :left
      Tk::UTF8_String.new("Connecting to server...")
      grid column: 0, row: 0
      grid_configure sticky: "w"
    }
    frame.grid_columnconfigure(0, weight: 1)
    frame.pack(side: :bottom, fill: :x)

    frame = TkFrame.new(root).pack(fill: :both, expand: false)

    Ttk::Label.new(frame) {
      wraplength 790
      justify :left
      text Tk::UTF8_String.new("Make sure the FTP server on the device is running and the settings are in the previous window. Browse to where you want the music and playlists to be copied to and press \"Choose Path\"")
      grid column: 0, row: 0
      grid_configure sticky: "w"
    }

    @ftp_path = Tk::Label.new(frame) {
      wraplength 790
      justify :left
      text Tk::UTF8_String.new("")
      grid column: 0, row: 1
      grid_configure sticky: "w"
    }

    frame = TkFrame.new(root).pack(fill: :both, expand: true)
    build_table(frame)
  end

  def build_table(frame)
    @select_ftp_path_window_table_data = tab  = TkVariable.new_hash
    rows = 0
    cols = 3

    scroll = nil
    params = { rows: rows + 1, cols: cols, variable: tab, titlerows: 1, titlecols: 0,
               roworigin: -1, colorigin: 0, #colwidth: 4, width: 8, height: 8,
               maxwidth: 780, height: 400, cursor: 'top_left_arrow', borderwidth: 2,
               flashmode: false, state: :disabled
    }
    $scroll_target = @table = table = Tk::TkTable.new(frame, params) {
      pack('side' => 'left', 'fill' => 'y', 'expand' => 1)
    }
    table.set_width([[0,8],[1,12],[2,120]])

    $scroll = scroll = table.yscrollbar(TkScrollbar.new(frame) {
      pack('side' => 'left', 'fill' => 'y', 'expand' => 0)
    })
    table.lower

    directory = { bg: "gray75", relief: :raised }
    file = { bg: "gray75", relief: :flat }
    table.tag_configure("directory", directory)
    table.tag_configure("left-directory", directory.merge(anchor: "w", justify: :left))
    table.tag_configure("file", :bg=>'gray75', :relief=>:flat)
    table.tag_configure("left-file", file.merge(anchor: "w", justify: :left))

    #logo = TkPhotoImage.new(:file=>File.join(File.dirname(File.expand_path(__FILE__)), '../../tcllogo.gif'))
    #table.tag_configure('logo', :image=>logo, :showtext=>true)

    # clean up if mouse leaves the widget
    table.bind('Leave', proc{|w| w.selection_clear_all}, '%W')

    # highlight the cell under the mouse
    table.bind('Motion', proc{|w, x, y|
      Tk.callback_break if w.selection_include?(TkComm._at(x,y))
      w.selection_clear_all
      #puts "x,y #{x},#{y} #{TkComm._at(x,y).inspect}"
      #w.selection_set(TkComm._at(x,y))
      w.selection_set(TkComm._at(30,y), TkComm._at(460,y))
      Tk.callback_break
      ## "break" prevents the call to tkTableCheckBorder
    }, '%W %x %y')

    # mousebutton 1 toggles the value of the cell
    # use of "selection includes" would work here
    table.bind('1', proc{|w, x, y|
      #rc = w.curselection[0]
      rc = w.index(TkComm._at(x,y))
      puts("rc: #{rc.inspect}, tab[rc]: #{tab[rc]}")
      select_path_list_path("#{@ftp_path.text}#{tab[rc]}/")
=begin
      if tab[rc] == 'ON'
        tab[rc] = 'OFF'
        w.tag_cell('OFF', rc)
      else
        tab[rc] = 'ON'
        #w.tag_cell('ON', rc)
        w.tag_cell('logo', rc)
      end
=end
    }, '%W %x %y')

    # initialize the array, titles, and celltags
    tab[-1, 0] = ""
    tab[-1, 1] = "Size"
    tab[-1, 2] = "Name"

    0.step(rows) {|i|
      0.step(cols){|j|
        puts("tab #{i},#{j}")
        #tab[i,j] = "#{i},#{j}"
        table.tag_cell('OFF', "#{i},#{j}")
      }
    }
  end

  def connect_ftp
    @status_text_label.configure(text: Tk::UTF8_String.new("Status: Connecting..."))
    puts("Connecting...")
    status_text_label = @status_text_label
    instance = self

    Thread.new {
      begin
        settings = Settings.instance.values
        puts "setup ftp"
        instance.select_ftp_path_ftp = ftp = Net::FTP.open(settings[:ftp_ip], port: settings[:ftp_port], open_timeout: 1)
        puts "login"
        ftp.login(settings[:ftp_username], settings[:ftp_password])
        ftp.ls
        status_text_label.configure(text: "Status: Connected")
        select_path_list_path("/")
      rescue Net::OpenTimeout
        status_text_label.configure(text: Tk::UTF8_String.new("Couldn't connect to FTP server. Check your FTP settings, make sure the FTP is running on the device, check that you're on the same network as the device, and check your firewall."))
      rescue Exception => e
        status_text_label.configure(text: Tk::UTF8_String.new("#{e.class.name}: #{e.to_s}"))
        raise
      end
    }
  end

  def add_up_directory(path)
    @select_ftp_path_window_table_data[0, 0] = "D"
    @select_ftp_path_window_table_data[0, 1] = nil
    @select_ftp_path_window_table_data[0, 2] = SelectMusicDirectoryUi::UP_ONE_DIR_NAME

    @table.tag_cell("directory", "0,0")
    @table.tag_cell("directory", "0,1")
    @table.tag_cell("left-directory", "0,2")
  end

  def select_path_list_path(path)
    puts("1")
    @status_text_label.configure(text: Tk::UTF8_String.new("Status: Getting directory contents..."))
    puts("2")
    split_path = path.split("/")
    puts("3")
    if split_path.last == SelectMusicDirectoryUi::UP_ONE_DIR_NAME
      2.times { split_path.pop }
      path = split_path.join("/") + "/"
    end
    puts("4")

    puts("LAUNCH THREAD NOW")
    Thread.new {
      puts("IN THREAD NOW")
      begin
        @select_ftp_path_ftp.chdir(path)
        ls_result = @select_ftp_path_ftp.ls
        @status_text_label.configure(text: Tk::UTF8_String.new("Status: Parsing directory contents..."))

        #byebug
        if path == "/" || path == ""
          @table.configure(rows: ls_result.length + 1)
          row = 0
        else
          @table.configure(rows: ls_result.length + 2)
          add_up_directory(path) 
          row = 1
        end

        ls_result.each do |e|
          entry = Net::FTP::List.parse(e)

          @select_ftp_path_window_table_data[row, 0] = entry.file? ? "F" : "D"
          @select_ftp_path_window_table_data[row, 1] = entry.file? ? entry.filesize : nil
          @select_ftp_path_window_table_data[row, 2] = entry.basename
          puts("set #{row}, 2 to #{entry.basename}")

          @table.tag_cell(entry.file? ? "file" : "directory", "#{row},0")
          @table.tag_cell(entry.file? ? "file" : "directory", "#{row},1")
          @table.tag_cell("left-" + (entry.file? ? "file" : "directory"), "#{row},2")

          row += 1
        end
        puts "Set path to #{path}"
        @ftp_path.configure(text: Tk::UTF8_String.new(path))
        @status_text_label.configure(text: Tk::UTF8_String.new("Status: Connected"))
      rescue Exception => e
        @status_text_label.configure(text: Tk::UTF8_String.new("#{e.class.name}: #{e.to_s}"))
        raise
      end
    }
  end
end
