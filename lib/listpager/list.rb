require 'ncursesw'
require 'listpager/color'
require 'listpager/scrollbar'

module Listpager
  class List
    INDICATOR    = ' ➤ '
    NO_INDICATOR = '   '

    # U+2003 "EM SPACE".  Ncurses' range-combining "optimizations" fuck up normal
    # and non-breaking spaces.  For display, this is fine.  For copying, you'd
    # have a scrollbar in the way anyway.  I fear newer releases of ncurses will
    # get smarter and also consider this "blank" for optimizations.
    BLANK_SPACE  = ' '

    def on_select_change(i)
    end

    def on_key_press(k)
    end

    attr_reader :window
    attr_accessor :values
    attr_reader :selected
    attr_reader :offset
    attr_reader :scrollbar
    attr_reader :title

    def initialize(window)
      @window = window
      @title = nil
      @values = []
      @selected = 0
      @offset = 0
      @dirty = true
      @scrollbar = Scrollbar.new(self)
    end

    def dirty!(value = true)
      @dirty = value
    end

    def dirty?
      @dirty
    end

    def title=(v)
      if v != @title
        @title = v
        dirty!
      end
      @title
    end

    def offset=(v)
      dirty! if v != @offset
      v = 0 if v < 0
      @offset = v
    end

    attr_reader :selected
    def selected=(v)
      minx, miny = getminxy
      maxx, maxy = getmaxxy

      v = [0, v, values.size - 1].sort[1]
      screenh = maxy - miny

      self.offset = [v + miny - 1, offset, (v + miny + 1) - screenh].sort[1]

      if v != @selected
        dirty!
        @selected = v
        on_select_change(v)
      end

      return @selected
    end


    def key_input(value)
      maxx, maxy = getmaxxy

      case value
        when Ncurses::KEY_UP
          self.selected -= 1
        when Ncurses::KEY_DOWN
          self.selected += 1
        when Ncurses::KEY_PPAGE
          self.selected -= maxy - 1
        when Ncurses::KEY_NPAGE
          self.selected += maxy - 1
        else
          on_key_press(value)
      end
    end

    def dirty!(v = true)
      @dirty = v
    end

    def normalize(s)
      s.gsub(/[^[:print:]]/, '')
    end

    def getminxy
      x, y = 0, 0
      y += 1 if title
      [x, y]
    end

    def getmaxxy
      maxx, maxy = [], []
      window.getmaxyx(maxy, maxx)
      [maxx[0], maxy[0]]
    end

    def space_pad(s, w)
      nspaces = (w - s.size)
      nspaces = 0 if nspaces < 0
      s + (BLANK_SPACE * (w - s.size))
    end

    def render_title
      maxx, maxy = getmaxxy
      if title
        window.color_set(Color[:title], nil)
        window.move(0, 0)
        window.addstr(space_pad(' ' + title, maxx))
      end
    end

    def render
      return false if ! dirty?

      render_title

      maxx, maxy = getmaxxy
      minx, miny = getminxy

      (miny...maxy).each do |i|
        window.color_set(Color[:list_default], nil)

        list_index = (offset + i) - miny
        window.move(i, 0)
        indicator = nil

        fixed_len = maxx - scrollbar.width

        if list_index == selected
          window.color_set(Color[:list_selected], nil)
          indicator = INDICATOR
        else
          indicator = NO_INDICATOR
        end

        string = values[list_index] || ''
        string = normalize(string)
        string = indicator + string

        if string.size < fixed_len
          string += (BLANK_SPACE * (fixed_len - string.size))
        elsif string.size > fixed_len
          string = string[0...fixed_len]
        end
        window.addstr(string)
      end

      scrollbar.render
      dirty!(false)
      return true
    end
  end
end
