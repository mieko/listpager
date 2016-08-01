# Note: This is a hack to work around ncursesw not building on macOS.
# Hopefully it can go away soon.

if RUBY_PLATFORM =~ /\bdarwin/i
  require 'ncurses'
else
  require 'ncursesw'
end
