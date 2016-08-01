require 'ncurses'

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

    def on_select_change
      puts "select #{selected} #{values[selected]}"
    end

    def on_key_press(k)
      puts "keypress #{key_name(k)} #{selected} #{values[selected]}"
    end

    attr_reader :window
    attr_accessor :values
    attr_reader :selected
    attr_reader :offset
    attr_reader :scrollbar

    def initialize(window)
      @window = window
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

    def offset=(v)
      dirty! if v != @offset
      @offset = v
    end

    attr_reader :selected
    def selected=(v)
      maxx, maxy = getmaxxy

      v = [0, v, values.size - 1].sort[1]
      self.offset = [v - maxy + 1, offset, v].sort[1]

      if v != @selected
        dirty!
        on_select_change
      end

      return (@selected = v)
    end

    def key_name(v)
      @m ||= {
        27  => 'esc',
        10  => 'enter',
        260 => 'left',
        261 => 'right',
        127 => 'backspace',
        330 => 'delete',
        ' ' => 'space',
      }
      @m[v] || (v < 255 && v.chr.match(/[[:print:]]/) ? v.chr : "\##{v}")
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

    def getmaxxy
      maxx, maxy = [], []
      window.getmaxyx(maxy, maxx)
      [maxx[0], maxy[0]]
    end

    def render
      return false if ! dirty?

      maxx, maxy = getmaxxy

      (0...maxy).each do |i|
        window.color_set(Color[:list_default], nil)

        list_index = offset + i
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
