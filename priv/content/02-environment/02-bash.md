# bash

After you log on a linux system you get a shell promt like

```bash
user_name@machine_name:~$
```

A shell is started, and now you can interact with your system.
A most commonly used shell is the [GNU Bash][bash].

## buildins

The `bash` includes a [bunch of commands][buildin], where some of them is used quiet often.

### alias 

When you use commands quiet often, you can create an `alias` for it.
For example you can create an alias for `cd ..` with

```bash
$ alias ..="cd .." 
```

Now you can type `..` to get into the parent directory.

When you use a command always with the same parameters, you can create an alias as well, 
and override the command name.

```bash
alias cal="ncal -wMb"
```

If you enter aditional parameters, the parmeters will be merged.

```bash
$ cal

November 2019        
 w| Mo Tu We Th Fr Sa Su   
44|              1  2  3   
45|  4  5  6  7  8  9 10   
46| 11 12 13 14 15 16 17   
47| 18 19 20 21 22 23 24   
48| 25 26 27 28 29 30      
                                  
$ cal -3
                                     2019
          October                   November                   December           
 w| Mo Tu We Th Fr Sa Su    w| Mo Tu We Th Fr Sa Su    w| Mo Tu We Th Fr Sa Su   
40|     1  2  3  4  5  6   44|              1  2  3   48|                    1   
41|  7  8  9 10 11 12 13   45|  4  5  6  7  8  9 10   49|  2  3  4  5  6  7  8   
42| 14 15 16 17 18 19 20   46| 11 12 13 14 15 16 17   50|  9 10 11 12 13 14 15   
43| 21 22 23 24 25 26 27   47| 18 19 20 21 22 23 24   51| 16 17 18 19 20 21 22   
44| 28 29 30 31            48| 25 26 27 28 29 30      52| 23 24 25 26 27 28 29   
                                                       1| 30 31             
```

### export

Environment variables can be created with

```bash
$ export KEY=VALUE 
```

To show the content of `KEY` you can do

```bash
$ echo $KEY
VALUE
```

### history

You will type a lot of commands over the time, and sometimes, you might want to remember, how the command was executed.
Here the `history` comes in. 

```bash
$ history 
```

will show you all the commands entered. 

### pushd / popd

You can add a directory to a stack like

```bash
$ pushd $(pwd) 
```

and later on you can return to the stored path with

```bash
$ popd 
```

This can be handy, when you are working with bash scripts.


### command

When you want to know, where a command is located, you can do something like

```bash
$ command -v vi
/usr/bin/vi
$ command -v ..
alias ..='cd ..'
$ command -v pushd
pushd
```

As you can see this command is quite usefull, when you want to know, what is behind a command.

## scripting

A shell script starts with a [shebang][shebang] 

```bash
#!/bin/bash
```

The script will be executed within a new process wich will exit with `0` if everything is fine.

### variables

You can define variables within a script as following

```bash
#!/bin/bash
TEST="what_ever"
cat $TEST
```

This will output `what_ever` after exiting. 

The variables `$1`, `$2`, ... are reserved for parameters

### if

```bash
#!/bin/bash
if [ ! -z $1 ]; then
  echo $1;
else
  echo "parameter not given";
fi
```

<!--
### case

### while

### exit

-->

## ~/.bashrc

After a user is created, a basic `~/.bashrc` file is created for you. 
When you open this file for a first time, it might be a little bit confusing,
but you might to addjust some of the default settings.

For a full bash history you should change the variables

```bash
HISTCONTROL=ignoreboth
HISTSIZE="infinite"
```

Now empty lines and duplicates won't be stored and the history file will grow infinitely.

I would not change the `~/.bashrc` so much and place your custom commands in a seperate file,
which will be interesting, when you working on your [setup script][setup].

```bash
if [ -f $HOME/.bashrc_additional_config ]; then
    source $HOME/.bashrc_additional_config
fi
```

When you have choosen your favorite editor, you should define it with

```bash
export EDITOR=vim
```

If you want to configure the behaviour of `bash` you can use the `set` command.

```
set -o vi
```

will enable the `vi` style line editing mode.

[bash]: https://www.gnu.org/software/bash/
[shebang]: https://en.wikipedia.org/wiki/Shebang_(Unix)
[buildin]: http://manpages.ubuntu.com/manpages/bionic/man7/bash-builtins.7.html
[setup]: /environment/setup.html
