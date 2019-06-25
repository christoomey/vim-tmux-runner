VTR [Vim Tmux Runner]
=====================

A simple, vimscript only, command runner for sending commands from vim to tmux.

Usage
-----

VTR provides a handful of commands for managing and interacting with [tmux][],
the terminal multiplexer. The main command is:

``` vim
VtrSendCommandToRunner
```

This command will prompt for a command to run, then send it to the runner pane
for execution. Subsequent calls to `VtrSendCommandToRunner` will reuse the
provided command.

If you would like VTR to create a runner pane if one doesn't exist while issuing
a command, a bang version can be used: `VtrSendCommandToRunner!`.

VTR provides configuration options that allow for control over the size and
location of the VTR runner pane. In addition, VTR provides commands to resize,
reorient, and even detach the runner pane making the interaction as painless as
possible.

For a complete summary of the available commands and configuration options in
VTR, check [the included doc file][].

You can watch a [short demo][] by [Jack Franklin][] recorded at [Vim London][].

Installation
------------

If you don't have a preferred installation method, I recommend using
[vim-plug][]:

```vim
Plug 'christoomey/vim-tmux-runner'
```

*Note* - you'll need to have a relatively recent (2.0+) version of Tmux to use
this plugin.

[vim-plug]: https://github.com/junegunn/vim-plug

Python Notes
------------

If you are using python, or any other language with syntactic whitespace, you
will likely want to change the following settings to better support the
required whitespace:

``` vim
let g:VtrStripLeadingWhitespace = 0
let g:VtrClearEmptyLines = 0
let g:VtrAppendNewline = 1
```

Additionally, if you are using ipython, you will need to ensure it is
installed with proper readline support. Ref [this Stack Overflow thread][] and
answer for more detail.

You will also need to start ipython with auto-indentation disabled, which can
be done with the following `ipython --no-autoindent`.

[this Stack Overflow thread]: http://stackoverflow.com/a/1840304/2751777

Inspiration
-----------

This plugin is heavily inspired by the functionality in the [Vimux][] plugin.
This plugin aims to implement a similar feature set while not requiring Vim
with ruby requirement. In addition a few new commands not found in Vimux have
been added to provide additional control over the tmux runner pane.

[the included doc file]: https://github.com/christoomey/vim-tmux-runner/blob/master/doc/vim-tmux-runner.txt
[Pathogen]: https://github.com/tpope/vim-pathogen
[Vundle]: https://github.com/gmarik/vundle
[tmux]: http://tmux.sourceforge.net/
[Vimux]: https://github.com/benmills/vimux
[short demo]: https://vimeo.com/126420226
[Jack Franklin]: https://github.com/jackfranklin
[Vim London]: http://www.meetup.com/Vim-London/
