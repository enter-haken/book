# packages

Packages can consist of multiple commands, and often have own configuration files. 
This is a overview of usefull packages and their configuration.

Beyond the base commands, there are some packages, that might become handy during the development process.

<!--more-->

## awk

| distribution | package name    |
| ------------ | --------------- |
| gentoo       | `sys-apps/gawk` |


## jq


| distribution | package name   |
| ------------ | -------------- |
| ubuntu       | `jq`           |
| gentoo       | `app-misc/jq`  |

## git

| distribution | package name   |
| ------------ | -------------- |
| ubuntu       | `git`          |
| gentoo       | `dev-vcs/git`  |

## tig

| distribution | package name   |
| ------------ | -------------- |
| ubuntu       | `tig`          |
| gentoo       | `dev-vcs/tig` |

## make

| distribution | package name |
| ------------ | ------------ |
| ubuntu       | `make`       |
| gentoo       | `sys-devel/make` |

## ssh

| distribution | package name       |
| ------------ | ------------------ |
| ubuntu       | `openssh-client`   |
| gentoo       | `net-misc/openssh` |

<!--
/usr/bin /usr/bin/scp /usr/bin/sftp /usr/bin/ssh /usr/bin/ssh-add /usr/bin/ssh-agent /usr/bin/ssh-argv0 /usr/bin/ssh-copy-id /usr/bin/ssh-keygen /usr/bin/ssh-keyscan /usr/bin/slogin
-->

### generating keys

After installing the `ssh` package you can now add ssh keys to your local user

```bash
$ ssh-keygen -t rsa -b 4096
```

Now the `~/.ssh/id_rsa` file contains your `private key`, and the `~/.ssh/id_rsa.pub` file contains your `public key`.
The `private key` should never be touched, or given away. 
The `public key` can be added to the `./ssh/authorized_keys` file on a remote server.

When you are working with `ssh` on a server running on the internet, you should deactivate the password login.

Therefore you need to edit the `/etc/ssh/sshd_config` file and change the following lines.

```
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
```

After these changes you have to reload the deamon

```
$ sudo /etc/init.d/ssh restart
```

Now you can check your new settings.

```bash
$ ssh user@server -o PubkeyAuthentication=no
user@server: Permission denied (publickey).
```

## tree

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `tree`          |
| gentoo       | `app-text/tree` |

## locate

| distribution | package name       |
| ------------ | ------------------ |
| gentoo       | `sys-apps/mlocate` |

## tmux 

use mouse witin tmux
```
setw -g mouse on
```

use 256 colors

```
set -g default-terminal "screen-256-color"
```

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `tmux`          |
| gentoo       | `app-misc/tmux` |

## evince

| distribution | package name      |
| ------------ | ----------------- |
| ubuntu       | `evince`          |
| gentoo       | `app-text/evince` |

## feh

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `feh`           |
| gentoo       | `media-gfx/feh` |


## less

| distribution | package name    |
| ------------ | --------------- |
| gentoo       | `sys-apps/less` |

# graphviz

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `graphviz`      |


# htop 

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `htop`      |

# procps

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `procps`      |

This package contains a bunch of small tools, which are usefull when you work with the `/proc` filesystem.

For example, if you want to delete all zombie processes on a system you can do something like

```bash
$ kill $(ps -A -ostat,ppid | awk '/[zZ]/ && !a[$2]++ {print $2}')

```

# imagemagick 

| distribution | package name            |
| ------------ | ----------------------- |
| ubuntu       | `imagemagick`           |
| gentoo       | `media-gfx/imagemagick` |

# qpdf 

| distribution | package name            |
| ------------ | ----------------------- |
| ubuntu       | `qpdf`                  |
| gentoo       | `app-text/qpdf`         |

With this package, you can extract pages from a given pdf file.

```bash
qpdf input.pdf --pages . 1-10 -- output.pdf
```

This command extracts the pages one to ten from a given `input.pdf` file and saves them to `output.pdf`.


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
