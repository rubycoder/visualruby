
class VR_Document < GtkSource::View
  
  include GladeGUI
  include VR_TextViewCommon
  
  attr_accessor :full_path_file, :title  

  def initialize(full_path_file, title_label, main)
    @main = main
    super()
    @title = title_label #reference to label on tab
    @full_path_file = full_path_file
    reload_from_disk() 
    hilight_current_line = true
    show_right_margin = true
    right_margin_position = 80
    auto_indent = true
    if ["", ".gemspec", ".erb"].include?(File.extname(full_path_file)) 
      buffer.language = GtkSource::LanguageManager.new.get_language("ruby")
    else  
      buffer.language = GtkSource::LanguageManager.new.guess_language(full_path_file)
    end
    buffer.highlight_syntax = true
    buffer.highlight_matching_brackets = false
    @hilight = buffer.create_tag("hilight", { "background" => "#FFF0A0" })
    buffer.signal_connect("changed") { remove_tag(@hilight) }
    self.show_line_numbers = true 
    self.insert_spaces_instead_of_tabs = true
    self.indent_width = $VR_ENV_GLOBAL.tab_spaces.to_i
    self.highlight_current_line = true
    self.set_cursor_visible(true)
    update_style()
  end

  def update_style()
    override_font(Pango::FontDescription.new($VR_ENV_GLOBAL.font_name))
    tab_array = Pango::TabArray.new(1, true)
    tab_array.set_tab(0, Pango::TAB_LEFT, $VR_ENV_GLOBAL.tab_spaces.to_i * 8)  
    set_tabs(tab_array)
  end

  def reload_from_disk()
    buffer.text = File.open(@full_path_file, "r").read if File.file?(@full_path_file.to_s) #protect against nil to_s        
    buffer.modified = false
    @modified_time = mod_time()
  end

  def modified_time_matches()  
    return true if @modified_time == mod_time()
    text = "The file: <b>#{@full_path_file}</b>\n has been modified since you loaded it:\n\nYou loaded: #{@modified_time}\nOn disk: #{mod_time().to_s}\n\nDo you wnat to keep this version?\n"  
    ans = alert(text, headline: "Warning!", width: 400, button_yes: "Keep Current Version", 
            button_no: "Reload Disk Version", button_cancel: "Cancel", parent: @main)
    if ans == true # yes, keep current 
      write_to_disk()
      return true
    elsif ans == false # Reload From Disk
      reload_from_disk()
    end 
    return false #abort!
  end

  def write_to_disk(fn = @full_path_file)
    @full_path_file = fn
    File.open(fn, "w")  { |f| f.puts(buffer.text) }
    buffer.modified = false
    @modified_time = mod_time()
    @title.label = File.basename(fn)
    return true  
  end





 def jump_to_line(line_num, search_str = nil)
    while (Gtk.events_pending?)
      Gtk.main_iteration
    end
    hilight_line(line_num)
    iter = buffer.get_iter_at(:line => line_num - 1)
    buffer.place_cursor(iter)    
    mark = buffer.get_mark("insert")
    scroll_to_mark(mark, 0.1, true, 0.0, 0.5)
    select_text(line_num - 1, search_str) if search_str
  end
  
  def hilight_line(line)
    remove_tag(@hilight)
    apply_tag_to_line(line-1, @hilight, nil)
  end

  def comment()
    return unless buffer.has_selection?
    s,e = get_selected_lines()
    (s..e).each do |i|
      iter, iter_end = get_line_iters(i)
      iter_end.offset = iter.offset+1
      chr = buffer.get_text(iter, iter_end, false)
      buffer.insert(iter, "#")
    end  
  end

  def un_comment()
    return unless buffer.has_selection?
    s,e = get_selected_lines()
    (s..e).each do |i|
      iter, iter_end = get_line_iters(i)
      next if iter_end.offset <=  iter.offset + 1
      iter_end.offset = iter.offset+1
      chr = buffer.get_text(iter, iter_end, false)
      buffer.delete(iter, iter_end) if chr == "#"        
    end  
  end

  def get_selected_lines()
    return unless buffer.has_selection?
    s,e = buffer.selection_bounds
    return s.line, e.line 
  end

  def replace(str)
    return unless buffer.has_selection?
    s,e = buffer.selection_bounds
    buffer.delete(s,e)
    buffer.insert_at_cursor(str)
  end

  def selected_text()
    s,e = buffer.selection_bounds
    buffer.get_text(s, e, false)
  end
  
  def empty?()
    return buffer.text.strip == ''
  end

  def self.get_class_title(source_code)
    cn = /^\s*class\s+(\b\w+\b)/.match(source_code)
    cn == nil ? "Untitled" : cn[1] + ".rb" 
  end
  
  def mod_time()
    return File.file?(@full_path_file) ? File.stat(@full_path_file).mtime : nil
  end

end
     
