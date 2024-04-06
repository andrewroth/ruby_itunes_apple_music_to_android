class FtpWrapper
  CONNECTING_MSG = "Connecting..."
  CANT_CONNECT_MSG = "Couldn't connect to FTP server. Check your FTP settings, make sure the FTP is running on the device, check that you're on the same network as the device, and check your firewall."

	include Singleton
  include Logs
  
  def connect
    return if @ftp

    set_statuses(CONNECTING_MSG)

    begin
      settings = Settings.instance.values
      log("Net::FTP open call here")
      @ftp = Net::FTP.open(settings[:ftp_ip], port: settings[:ftp_port], open_timeout: 1)
      log("Net::FTP login call here")
      @ftp.login(settings[:ftp_username], settings[:ftp_password])
      #select_path_list_path("/")
    rescue Net::OpenTimeout
      log(CANT_CONNECT_MSG)
      set_statuses(CANT_CONNECT_MSG)
      raise
    rescue Exception => e
      s = "Error #{e.class.name}: #{e.to_s}"
      MainUi.instance.set_status(s)
      MainUi.instance.select_ftp_path_window&.instance.set_status(s)
      log(caller.join("\n\t"))
      raise
    end

    set_statuses("")
  end

  def set_statuses(s)
    MainUi.instance.set_status(s)
    MainUi.instance&.select_ftp_path_window&.instance&.set_status(s)
  end

  def chdir(path)
    log_command("chdir #{path}")
    run_command { @ftp.chdir(path) }
  end

  def ls
    log_command("ls")
    run_command { @ftp.ls }
  end

  def reconnect!
    @ftp = nil
    connect
  end

  def upload_text(path)
    run_command { @ftp.puttextfile(path) }
  end

  def upload_binary(local_path, remote_path = nil)
    log_command("putbinaryfile #{local_path.inspect} #{remote_path.inspect}")
    run_command { @ftp.putbinaryfile(local_path, remote_path) }
  end

  def download_text(path)
    @ftp.gettextfile(path)
  end

  def mkdir(path)
		begin
			run_command { @ftp.mkdir(path) }
		rescue Net::FTPPermError => e
			# TODO: probably should check directly from an "ls" of the parent directory whether this is really a file or directory...
			# if it's a directory, we can continue. If it's a file, we should mark this particular track as failed
			if e.to_s =~ /550 Already exists/
				log("already exists.. weird it wasn't in cache?")
			else
				raise
			end
		rescue Net::FTPReplyError => e
			raise unless e.to_s =~ /250 Directory created/
		end
  end

  def run_command
    begin
      yield
    rescue Errno::ECONNRESET
      reconnect!
      retry
    end
  end

  def ls_parsed
    ls.collect do |list_row|
      parsed = Net::FTP::List.parse(list_row)
      yield(parsed) if block_given?
      parsed
    end 
  end

  def log_command(s)
    log("command: #{s}")
  end
end
