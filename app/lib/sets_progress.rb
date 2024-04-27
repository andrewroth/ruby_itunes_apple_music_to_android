module SetsProgress
  # I like seeing the progress at 100% full, and step will go back to 0 when it hits maximum
  # Doing it this way doesn't have that problem
  def progress_step
    MainUi.instance.progress.value(MainUi.instance.progress.value + 1)

    # if the log tab is selected, do a very short sleep to make sure the UI refreshes
    # it makes the whole load or whatever is being done slower, but at least the user will see
    # log updates, and if they're on the log tab they probably want to see what's going on
    sleep(0.1) if MainUi.instance.log_tab_selected
  end

  def progress_value
    MainUi.instance.progress.value
  end

  def set_progress_max(max)
    MainUi.instance.progress.maximum(max)
  end

  def progress_max
    MainUi.instance.progress.maximum
  end

  def progress_max_f
    @max ||= progress_max.to_f
  end

  def set_progress_status(s, i: progress_value, max: nil)
    if max
      max_f = max.to_f
    else
      max = progress_max
      max_f = progress_max_f
    end
    set_main_status("[#{i}/#{max}, #{((i / max_f) * 100).round(1)}%] #{s}")
    sleep 0.1
  end

  def progress_clear
    MainUi.instance.progress.value = 0
  end

  def progress_complete
    log("complete progress")
    MainUi.instance.progress.value = progress_max
    sleep 0.1
    MainUi.instance.progress.value = 0
  end
end
