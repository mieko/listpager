require 'listpager/ncurses'

require 'listpager/color'

module Listpager
  class Scrollbar
    UP_ARROW   = '▴'
    DOWN_ARROW = '▾'

    attr_reader :list

    def initialize(list)
      @list = list
      @memo_keys = nil
      @memo_val = nil
    end

    def width
      1
    end

    def scroll_thumb_range
      maxx, maxy = getmaxxy

      # We memoize these based on the inputs that effect the output
      memo_keys = [list.values.size, list.offset, maxy]
      return @memo_val if @memo_keys == memo_keys

      # Ref: http://csdgn.org/inform/scrollbar-mechanics
      #  using original camelCasedVariableNames for clarity with the source.
      contentSize = list.values.size.to_f
      windowSize = maxy.to_f
      trackSize = windowSize - 2
      windowContentRatio = windowSize / contentSize
      gripSize = trackSize * windowContentRatio

      minimalGripSize = 1.0
      if gripSize < minimalGripSize
        gripSize = minimalGripSize
      end

      windowScrollAreaSize = contentSize - windowSize
      windowPosition = list.offset.to_f
      windowPositionRatio = windowPosition / windowScrollAreaSize

      trackScrollAreaSize = trackSize - gripSize
      gripPositionOnTrack = trackScrollAreaSize * windowPositionRatio

      st = 1 + gripPositionOnTrack.floor.to_i
      e = (st + gripSize.ceil).to_i

      st = 1 if st < 1
      e = maxy - 1 if e > maxy - 1

      @memo_keys = memo_keys
      return (@memo_val = st ... e)
    end

    def window
      list.window
    end

    def getmaxxy
      list.getmaxxy
    end

    def render
      maxx, maxy = getmaxxy
      x = maxx - self.width

      # If we don't need a scroll bar...
      return if list.values.size <= maxy

      # Both arrows
      window.color_set(Color[:scroll_arrow], nil)
      window.move(0, x)
      window.addstr(UP_ARROW)
      window.move(maxy - 1, x)
      window.addstr(DOWN_ARROW)

      # The full track
      window.color_set(Color[:scroll_track], nil)
      (1 ... maxy - 1).each do |y|
        window.move(y, x)
        window.addstr(' ')
      end

      # Scroll thumb on top of it
      window.color_set(Color[:scroll_thumb], nil)
      scroll_thumb_range.each do |y|
        window.move(y, x)
        window.addstr(' ')
      end

      # Set our drawing cursor at the origin
      window.color_set(Color[:list_default], nil)
      window.move(0, 0)
    end

    def can_scroll_up?
      list.offset > 0
    end

    def can_scroll_down?
      _, maxy = getmaxxy
      list.values.size > list.offset + maxy
    end
  end
end
