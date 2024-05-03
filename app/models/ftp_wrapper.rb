class FtpWrapper
  CONNECTING_MSG = "Connecting..."
  CANT_CONNECT_MSG = "Couldn't connect to FTP server. Check your FTP settings, make sure the FTP is running on the device, check that you're on the same network as the device, and check your firewall."
  DISCONNECTED_MSG = "Connection lost to FTP server."

  include Logs
  
  def self.instance
    @instance ||= FtpWrapper.new
  end

  def new
  end

  def countdown(num)
    if num == 0
      return
    else
      set_statuses("Retrying in #{num} seconds...")
      sleep 1
      countdown(num - 1)
    end
  end

  def reconnect!
    @ftp = nil
    connect(true)
  end

  def reconnect_repeatedly!
    @ftp = nil
    connect_repeatedly
  end

  def connect_repeatedly
    while @ftp.nil?
      sleep(2) unless @ftp
      countdown(5)
      begin
        connect
      rescue
      end
      break if @ftp
    end
  end

  def connect
    log("start0 #{self.object_id}")
    return if @ftp

    set_statuses(CONNECTING_MSG)

    log("start1 #{self.object_id}")

    begin
      settings = Settings.instance.values
      log("Net::FTP open call here")
      @ftp = Net::FTP.open(settings[:ftp_ip], port: settings[:ftp_port], open_timeout: 1)
      log("Net::FTP login call here")
      @ftp.login(settings[:ftp_username], settings[:ftp_password])
      #select_path_list_path("/")
    rescue Net::OpenTimeout, Net::FTPConnectionError
      log(CANT_CONNECT_MSG)
      set_statuses(CANT_CONNECT_MSG)
      raise
    rescue Exception => e
      s = "Error #{e.class.name}: #{e.to_s}"
      MainUi.instance.set_status(s)
      #MainUi.instance.select_ftp_path_window&.instance.set_status(s)
      log(caller.join("\n\t"))
      raise
    end

    log("end #{self.object_id}")

    set_statuses("")
  end

  def set_statuses(s)
    MainUi.instance.set_status(s)
    MainUi.instance&.select_ftp_path_window&.instance&.set_status(s)
  end

  def ls(path)
    log_command("ls #{path}")
    r = run_command { @ftp.ls(path) }
    #log(r)
    r
  end

  def upload_text(path, device_path)
    run_command { @ftp.puttextfile(path, device_path) }
  end

  def upload_binary(local_path, remote_path = nil)
    log_command("putbinaryfile #{local_path.inspect} #{remote_path.inspect}")
    begin
      run_command { @ftp.putbinaryfile(local_path, remote_path) }
    rescue Net::FTPPermError => e
      if e.to_s == "550 No such file or directory.\n" # go up and ensure directories exists

        log("#{e.to_s.inspect}, this usually means a parent directory doesn't exist...")
        dirs = File.dirname(remote_path).split("/")
        path = ""
        dirs.each do |dir|
          path = File.join(path, dir)
          log("trying to create #{path}")
          # try our best to create all the dirs
          begin
            mkdir(path)
          rescue
          end
          sleep 1
        end

        retry
      end
    end
  end

  def download_text(path)
    @ftp.gettextfile(path)
  end

  def mkdir(path)
    run_command do
      begin
        @ftp.mkdir(path)
      rescue Net::FTPPermError => e
        log("rescue #{e.class.name}: #{e.to_s}")

        # TODO: probably should check directly from an "ls" of the parent directory whether this is really a file or directory...
        # if it's a directory, we can continue. If it's a file, we should mark this particular track as failed
        if e.to_s =~ /Already exists/
          log("already exists.. weird it wasn't in cache? Continuing on..")
        else
          raise
        end
      rescue Net::FTPReplyError => e
        raise unless e.to_s =~ /250 Directory created/
      end
    end
  end

  def run_command
    begin
      yield
    rescue Errno::ECONNRESET, Errno::EPIPE, EOFError, Errno::ETIMEDOUT, Net::OpenTimeout, Errno::ECONNABORTED => e
      set_statuses("(#{e.to_s}) #{DISCONNECTED_MSG}")
      sleep 2
      countdown(5)
      reconnect_repeatedly!
      retry
    rescue Net::FTPPermError => e
      log("rescue #{e.class.name}: #{e.to_s}")

      # so weirdly, sometimes Net::FTPPermError ends up here, and a re-raise doesn't hit the other rescue in mkdir, so just do it here
      if e.to_s =~ /Already exists/
        log("already exists.. weird it wasn't in cache? Continuing on..")
      end
    rescue Exception => e
      log("Exception #{e.class.name}: #{e.to_s}... re-raising")
      raise
    end
  end

  def ls_parsed(path)
    ls(path).collect do |list_row|
      parsed = Net::FTP::List.parse(list_row)
      yield(parsed) if block_given?
      parsed
    end 
  end

  def log_command(s)
    log("command: #{s}")
  end
end
