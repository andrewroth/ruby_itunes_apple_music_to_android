module SetsStatus
  def set_main_status(msg)
    MainUi.instance.set_status(msg)
  end

  def set_select_ftp_path_status(msg)
    MainUi.instance&.select_ftp_path_window&.instance&.set_status(msg)
  end

  def sets_both_statuses(msg)
    set_main_status(msg)
    set_select_ftp_path_status(msg)
  end
end
