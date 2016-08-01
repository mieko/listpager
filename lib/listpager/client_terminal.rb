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
    attr_reader :mode

    def initialize
      @tty = File.open('/dev/tty', 'r+')
      @self_pipe = IO.pipe

      [@tty, *self_pipe].each do |io|
        io.sync = true
      end

      initialize_curses

      @list = List.new(Ncurses.stdscr)
      @mode = :append
      @buffer = ''
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

    def append_mode?
      @mode == :append
    end

    def process_command(line)
      if append_mode?
        case line
        when '\%%'
          list.values.push('%%')
          list.dirty!
        when '%%'
          @mode = :command
        else
          list.values.push(line)
          list.dirty!
        end
      else
        cmd, *args = Shellwords.split(line)
        begin
          case cmd
            when '%%', 'append-mode'
              @mode = :append
            when 'get-selected'
              list.selection_changed
            when 'select'
              list.selected = args.fetch(0).to_i
            when 'get-item'
              puts ["item", args.fetch(0), list.values[args.fetch(0).to_i]].join ' '
            when 'quit'
              raise Interrupt
          end
        rescue IndexError => e
          puts "error bad-command #{line}"
        end
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
            process_command(line.chomp)
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
