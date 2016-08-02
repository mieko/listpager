require 'ncursesw'
require 'shellwords'
require 'optparse'
require 'io/console'

require 'listpager/color'
require 'listpager/list'

module Listpager
  class ClientTerminal
    attr_reader :tty
    attr_reader :self_pipe
    attr_reader :list

    attr_reader :locked

    def initialize
      @tty = File.open('/dev/tty', 'r+')
      @self_pipe = IO.pipe
      @locked = false

      [@tty, *self_pipe].each do |io|
        io.sync = true
      end

      initialize_curses

      @list = List.new(Ncurses.stdscr)
      connect_list

      @buffer = ''
      @locked_buffer = []
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

    def connect_list
      cterm = self
      list.define_singleton_method :on_select_change do
        cterm.cmd!('is-selected', selected, selected_value, observe_lock: true)
      end

      list.define_singleton_method :on_key_press do |k|
        cterm.cmd!('key-pressed', cterm.key_name(k),
                   selected, selected_value, observe_lock: true)
      end
    end

    def initialize_curses
      screen = Ncurses.newterm(nil, @tty, @tty)
      Ncurses.set_term(screen)
      Ncurses.start_color
      Color.init
      Ncurses.use_default_colors
      Ncurses.cbreak
      Ncurses.stdscr.scrollok(false)
      Ncurses.stdscr.keypad(true)
      Ncurses.curs_set(0)
      Ncurses.noecho
      Ncurses.timeout(0)
    end

    def deinitialize
      Ncurses.echo
      Ncurses.nocbreak
      Ncurses.nl
      Ncurses.endwin
      @tty.close
    end

    def line!(line, observe_lock: false)
      if observe_lock && @locked
        @locked_buffer.push(line)
      else
        $stdout.puts line
        $stdout.flush
      end
    end

    def cmd!(*args, observe_lock: false)
      line!('%' + Shellwords.join(args.map(&:to_s)),
            observe_lock: observe_lock)
    end

    def process_command(argv)
      cmd, *args = argv
      case cmd
        # TODO: This to be refactored into CommandProcessor
        when 'quit'
          raise Interrupt

        when 'clear'
          list.values = []
          list.selected = 0
          list.dirty!

        when 'append'
          list.values.push(args.fetch(0))
          list.dirty!

        when 'lock'
          @locked = true
          cmd! 'lock'

        when 'unlock'
          @locked = false
          cmd! 'unlock'
          @locked_buffer.each do |line|
            line!(line)
          end
          @locked_buffer = []

        when 'get-title'
          cmd! 'title-is', @list.title
        when 'set-title'
          @list.title = args[0]
          cmd! 'title-is', @list.title

        when 'get-selected'
          cmd! 'selected-is', list.selected, list.selected_value
        when 'set-selected'
          list.selected = args.fetch(0).to_i
          cmd! 'seleted-is', list.selected, list.selected_value

        when 'get-item'
          cmd! 'item-is', args.fetch(0), list.values[args.fetch(0).to_i]
        when 'set-item'
          cmd! 'item-is'
      end
    end

    def process_line(line)
      if line[0] == '%' && line[1] != '%'
        cmd = Shellwords.split(line[1..-1])
        process_command(cmd)
      else
        if line[0] == '%'
          line = line[1..-1]
        end
        list.values.push(line)
        list.dirty!
      end
    end

    def consume_stdin(handles, fd)
      loop do
        begin
          @buffer << fd.read_nonblock(512)
        rescue EOFError
          handles.delete(fd)
          break
        rescue IO::WaitReadable
          break
        end
      end

      unless @buffer.empty?
        used = 0
        StringIO.new(@buffer).each_line do |line|
          if line[-1] == "\n"
            process_line(line.chomp)
            used += line.size
          else
            break
          end
        end
        @buffer = @buffer[used...-1]
      end
    end

    def consume_tty(handles, fd)
      while (ch = Ncurses.getch) != -1
        list.key_input(ch)
      end
    end

    # We get a character from self_pipe here telling us the window
    # has resized.
    def consume_self_pipe(handles, fd)
      code = fd.read(1)
      case code
        when 'R'
          new_size = IO.console.winsize
          Ncurses.resizeterm(*new_size)
          Ncurses.stdscr.clear
          list.dirty!
          list.render
          Ncurses.refresh
      end
    end

    def dispatch_fd(handles, fd)
      case fd
        when $stdin
          consume_stdin(@handles, fd)
        when tty
          consume_tty(@handles, fd)
        when self_pipe[0]
          consume_self_pipe(@handles, fd)
      end
    end

    def process_events
      @handles ||= [$stdin, tty, self_pipe[0]]

      return if @handles.empty?

      res = IO.select(@handles)
      if res && (readers = res[0])
        readers.each do |fd|
          dispatch_fd(@handles, fd)
        end
      end
    end

    def run
      trap 'WINCH' do
        self_pipe[1].tap do |fd|
          fd.write 'R'
          fd.flush
        end
      end

      begin
        loop do
          process_events
          if list.render
            Ncurses.redrawwin(list.window)
            Ncurses.refresh
          end
        end
      ensure
        deinitialize
      end
    end
  end
end
