# listpager

## Introduction
listpager is a terminal listbox.  It reads `stdin` for a list of items, goes all
interactive, and writes events to `stdout` as the user interacts with it.

![listpager in action](./doc/screenshot.png)

*listpager is in the left-hand panel*

listpager has proportional scroll bars, and can handle lists of any length.  It
handles terminal resizing just fine.

listpager was written as a component of [Cult][1], a fleet management tool.  Cult's
interactive mode is a specially-crafted tmux session consisting of tools that
talk to each other.  listpager is the node selection widget.

So basically, you may want to `popen` listpager, print a list of somethings to
its `stdin`, and listen on its `stdout`.  It'll go something like this:

![socat Listpager session](/doc/netcat-example.gif?raw=true "Controlling Listpager via TCP")


```ruby
listpager = IO.popen('listpager', 'r+')

# You don't want buffered IO
listpager.sync = true

50.times do |i|
  listpager.puts "Item #{i}"
end

listpager.puts "%set-selected 35"
```

If you want to play with the protocol, it's easiest to use two terminals and
`socat` (some implementations of `nc`/`netcat` do weird FD juggling which
ends up sending raw keyboard character input back to the client.).

Set up one like:

```bash
socat TCP-LISTEN:4500,reuseaddr EXEC:'listpager'
```

And a "client", like:
```bash
socat TCP:localhost:4500 -
```

Add some items on your keyboard, then enter some commands, prefixed by `%`.  If
you need an item that starts with a liter `%`, start it with `%%`.

There are a lot of obvious things the protocol could do, that it doesn't
currently.  It's way low-hanging fruit for any contributors.

## Protocol
listpager reads each item from stdin, and it becomes a list item.  As the user
arrows through the list, it outputs messages like:

`is-selected 21 apples` where `21` is the index into the list, and `apples` is
the caption.  Any other keys pressed on an item are written out like
`keypress enter apples`.


## Dependencies and Installation
Install listpager with `gem install listpager`.  It has few dependencies:
currently only `ncursesw`.  BUT IT DOESNT STOP THERE, of course:  For the
gem to build on a fresh Ubuntu, you'll need the following for widechar-
supporting libncurses development headers:

```bash
sudo apt install libncursesw5-dev
```

## Implementation Notes
curses is terrible but portable.  'curses' doesn't expose enough to be useful,
'ncursesw' is about as good as you'll do in Ruby.


## Upcoming Features
Right now, listpager does exactly what Cult needs, and nothing more.  For it to
be more functional, I'd like to add a few features:

  * `listpager -1`, for displaying a list, and just outputting the first item
    the user selected with enter, ala Zenity/dialog.
  * A search/filter activated with the `/` key
  * Mouse support, with scroll wheels.
  * Checkboxes
  * Extend command mode
  * `Listpager::Client`


## Contributing
~~I'm trying to keep listpager a single-file, small project, preferably under
500 lines of code.~~ I've given up on the idea that this can be functional,
correct, and maintainable in a single file that can be copied to a bin
directory. If you use listpager and know Ruby, please dig in and PR at its
github: https://github.com/mieko/listpager


## License
listpager is released under the MIT license.  Check out LICENSE.txt


## Authors
listpager was written by Mike A. Owens at meter.md.  mike@meter.md

[1]: https://github.com/metermd/cult "Cult"
