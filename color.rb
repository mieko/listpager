require 'ncurses'

class Color
  VALUES = {
    list_default: 0,
    list_selected: 1,
    scroll_track: 2,
    scroll_thumb: 3,
    scroll_arrow: 4,
  }.freeze

  def self.curses_lookup(c)
    Ncurses.const_get(c)
  end

  def self.init_color(c, fg, bg)
    fail "Invalid color: #{c.inspect}" if VALUES[c].nil?
    Ncurses.init_pair(VALUES[c], curses_lookup(fg), curses_lookup(bg))
  end

  def self.init
    init_color(:list_selected, :COLOR_BLACK, :COLOR_WHITE)
    init_color(:scroll_track, :COLOR_BLACK, :COLOR_BLACK)
    init_color(:scroll_thumb, :COLOR_WHITE, :COLOR_WHITE)
    init_color(:scroll_arrow, :COLOR_WHITE, :COLOR_BLACK)
  end

  def self.[](name)
    VALUES[name] or fail "invalid color name: #{name.inspect}"
  end
end
