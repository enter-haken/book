# broot

This one is quite new.
It exists no distribution package yet, but it is worth a look.

First of all you can download a [precompiled packages](https://dystroy.org/broot/documentation/installation/)

You can install `broot` from your download location

```bash
$ chmod +x broot && broot --install
```

Then you can copy the `broot` file into a folder within your path (this works for me, and may be changed within time).

To make `broot` more vimable, you can edit your configuration file `~/.config/broot/conf.toml` as following

```
[[verbs]]
key = "j"
execution = ":line_down"

[[verbs]]
key = "k"
execution = ":line_up"

[[verbs]]
key = "ctrl-u"
execution = ":page_up"

[[verbs]]
key = "ctrl-d"
execution = ":page_down"


[[verbs]]
key ="enter"
execution = "$EDITOR {file}"
```

The `$EDITOR` variable should be set to `/usr/bin/vim`.
