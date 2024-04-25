module XmlHelpers
  def unescape_xml(s)
    # https://stackoverflow.com/questions/1091945/what-characters-do-i-need-to-escape-in-xml-documents/17448222#17448222
    s.gsub("&#60;", "<")
      .gsub("&#62;", ">")
      .gsub("&#34;", "\"")
      .gsub("&#38;", "&")
      .gsub("&#39;", "'")
    # ex "Crumba%CC%88cher" -> "Crumbächer"; CC and 88 are hex bytes of a UTF-8 string encoding
      .gsub(/%([0-9,A-F]{2})/) { |s| [$1.to_i(16)].pack("c*").force_encoding("UTF-8") }
  end

  # "file:///Users/andrew/Music/iTunes/iTunes%20Media/" -> "//Users/andrew/Music/iTunes/iTunes%20Media/"
  def strip_url_file_path_starting(s)
    s.gsub(/^file:\/\/(localhost\/)?/, "")
  end
end
