module SetsProgress
  # I like seeing the progress at 100% full, and step will go back to 0 when it hits maximum
  # Doing it this way doesn't have that problem
  def progress_step
    MainUi.instance.progress.value(MainUi.instance.progress.value + 1)
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

  def set_progress_status(s)
    set_main_status("[#{progress_value}/#{progress_max}, #{((progress_value / progress_max_f) * 100).round(1)}%] #{s}")
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
