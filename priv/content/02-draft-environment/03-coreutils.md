# GNU coreutils 

The [GNU coreutils][coreutils] consists of a set of commands, which can be found on every GNU operating system. 
You may not need all of the commands, but some of them are used on a daily basis.
Within the shell you can combine them to get your work done.

<!--more-->

##  Essential user command binaries 

### /bin/echo

To show a line of text you can 


```bash
$ echo "test"
test
```

to show a string on standard out.

| parameter | description                                    |
| --------- | ---------------------------------------------- |
| `-e`      | enable interpretation of backslashes like `\n` |

### /bin/cat

If you want to print the content of a file to the standard output you can use

```bash
$ cat file.txt
```

You can also show multiple files.

```bash
$ cat one.txt two.txt three.txt
```

When no file is given, the standart imput is taken.

```bash
$ echo "test" | cat
test
```

You can also create files with


```bash
$ cat EOT > new_file.txt
> Test
> EOT
$ cat new_file.txt
Test
```

### /bin/ls

You can show the content of a directory with `ls`

```bash
/bin$ ls
bash                bzfgrep       dir            grep        loadkeys    nc             ntfstruncate  run-parts             systemd-inhibit                 which
brltty              bzgrep        dmesg          gunzip      login       nc.openbsd     ntfsusermap   sed                   systemd-machine-id-setup        whiptail
btrfs               bzip2         dnsdomainname  gzexe       loginctl    netcat         ntfswipe      setfacl               systemd-notify                  ypdomainname
```

| parameter                | description                             |
| ------------------------ | --------------------------------------- |
| `-a`, `--all`            | show all files                          |
| `-h`, `--human-readable` | print human readable file sizes         |
| `-l`                     | use long list format                    |
| `-r`, `--reverse`        | reverse sort order                      |
| `-t`                     | sort by modification time, newest first |
| `-1`                     | list one file by line                   |

The `-1` parameter is usefull, if used within a shell script.

Imagine you have files in a folder like 

```bash
$ ls -l
total 100
-rw-r--r--  1 jan.hake users     0 Dec 19 16:03 1
-rw-r--r--  1 jan.hake users     0 Dec 19 16:03 2
-rw-r--r--  1 jan.hake users     0 Dec 19 16:03 3
-rw-r--r--  1 jan.hake users     0 Dec 19 16:03 4
-rw-r--r--  1 jan.hake users     0 Dec 19 16:03 5
```

and you want to add a extension `.txt` to every file in this folder.

With a short script / call you can achieve this.

```bash
$ ls -1 | while read line
> do
> mv $line $line.txt
> done
$ ls -l
total 0
-rw-r--r-- 1 jan.hake users 0 Dec 19 16:03 1.txt
-rw-r--r-- 1 jan.hake users 0 Dec 19 16:03 2.txt
-rw-r--r-- 1 jan.hake users 0 Dec 19 16:03 3.txt
-rw-r--r-- 1 jan.hake users 0 Dec 19 16:03 4.txt
-rw-r--r-- 1 jan.hake users 0 Dec 19 16:03 5.txt
```

### /bin/touch

If you want to change the update and modification time of a file you can use `touch`.

```bash
$ touch test.txt
$ ls -al
total 100
drwxr-xr-x  2 jan.hake users  4096 Nov  6 07:47 .
drwxrwxrwt 40 root     root  94208 Nov  6 07:42 ..
-rw-r--r--  1 jan.hake users     0 Nov  6 07:47 test.txt
```

| parameter | description                    |
| --------- | ------------------------------ |
| `-a`      | change only access time        |
| `-m`      | change only modification time  |
| `-c`      | do not create any files        |

### /bin/chgrp

With `chgrp` you can change the group ownership of a file.

```bash
$ touch test.txt
$ sudo chgrp root test.txt 
$ ls -al
total 100
drwxr-xr-x  2 jan.hake users  4096 Nov  6 07:41 .
drwxrwxrwt 40 root     root  94208 Nov  6 07:41 ..
-rw-r--r--  1 jan.hake root      0 Nov  6 07:41 test.txt
```

In this example you create a file `test.txt` and give the ownership to `root`.

### /bin/chmod

If you want to make a file executable you can use `chmod` with the parameter `+x`

```bash
$ cat << EOT > test.sh
> #!/bin/bash
> echo "test"
> EOT
$ chmod +x test.sh 
$ ./test.sh 
test
```

### /bin/chown

Changing the ownership of a file can be done with `chown`.

```bash
$ touch test.txt 
$ ls -al
total 100
drwxr-xr-x  2 jan.hake users  4096 Nov  6 08:43 .
drwxrwxrwt 41 root     root  94208 Nov  6 08:43 ..
-rw-r--r--  1 jan.hake users     0 Nov  6 08:43 test.txt
$ sudo chown root:root test.txt
$ ls -al
total 100
drwxr-xr-x  2 jan.hake users  4096 Nov  6 08:43 .
drwxrwxrwt 41 root     root  94208 Nov  6 08:43 ..
-rw-r--r--  1 root     root      0 Nov  6 08:43 test.txt
jan.hake@lb-d-do-sw-w-04:/tmp/chgrp_Test$ 
```

| parameter           | description                  |
| ------------------- | ---------------------------- |
| `-R`, `--recursive` | change ownership recursively |

### /bin/cp

You can copy a file with `cp`.

```bash
$ touch test.txt 
$ cp test.txt test_2.txt
$ ls
test_2.txt  test.txt
```

| parameter                 | description                  |
| ------------------------- | ---------------------------- |
| `-R`, `-r`, `--recursive` | copy all files recursively   |

With the `-r` parameter you can copy complete subtrees, if you have the access rights.

<!--
### /bin/dd
-->

### /bin/df

If you want to know, disk space is left on your available mounted partitions, you can do a `df` to get a quick overview.


```bash
$ df -h
Filesystem                              Size  Used Avail Use% Mounted on
udev                                     16G     0   16G   0% /dev
tmpfs                                   3.2G  3.5M  3.2G   1% /run
/dev/nvme0n1p3                          464G  138G  303G  32% /
tmpfs                                    16G  1.3G   15G   8% /dev/shm
tmpfs                                   5.0M  4.0K  5.0M   1% /run/lock
...
```
| parameter                | description                        |
| ------------------------ | ---------------------------------- |
| `-h`, `--human-readable` | show sizes in a human readable way |

### /bin/ln

Create a link to a file.

```bash
$ touch test.txt 
$ ln -s test.txt test
$ ls -al
total 100
drwxr-xr-x  2 jan.hake users  4096 Nov  6 11:51 .
drwxrwxrwt 40 root     root  94208 Nov  6 11:51 ..
lrwxrwxrwx  1 jan.hake users     8 Nov  6 11:51 test -> test.txt
-rw-r--r--  1 jan.hake users     0 Nov  6 11:51 test.txt
```

This creates a soft link `test` to the file `test.txt`
If the file `test.txt` file is deleted, the link will not work any more.
Having a hard link (default) will still have a link on the original content.

| parameter                | description                        |
| ------------------------ | ---------------------------------- |
| `-s`, `--symbolic`       | create a symbolic link             |


### /bin/mkdir

You can create new directories with the `mkdir` command.

```bash
$ mkdir test
$ ls -al
total 104
drwxr-xr-x  3 jan.hake users  4096 Nov  6 12:00 .
drwxrwxrwt 40 root     root  94208 Nov  6 11:56 ..
drwxr-xr-x  2 jan.hake users  4096 Nov  6 12:00 test
```

To create multiple directories at once you can use the following syntax

```bash
$ mkdir {one,two,three}
$ ls -al
total 112
drwxr-xr-x  5 jan.hake users  4096 Nov  6 12:01 .
drwxrwxrwt 40 root     root  94208 Nov  6 12:01 ..
drwxr-xr-x  2 jan.hake users  4096 Nov  6 12:01 one
drwxr-xr-x  2 jan.hake users  4096 Nov  6 12:01 three
drwxr-xr-x  2 jan.hake users  4096 Nov  6 12:01 two
```

If you want to create a tree structure, you can

```bash
$ mkdir -p one/two/tree
$ ls -R
.:
one

./one:
two

./one/two:
tree

./one/two/tree:
```

| parameter                | description                        |
| ------------------------ | ---------------------------------- |
| `-p`, `--parents`        | create parents, if not exists      |

### /bin/rm

Removing files can be done with 

```bash
$ touch test.txt 
$ ls
test.txt
$ rm test.txt 
$ ls
$
```

| parameter                 | description                    |
| ------------------------- | ------------------------------ |
| `-f`, `--force`           | ignore non existent files      |
| `-r`, `-R`, `--recursive` | remove everything recursively  |

`WARNING`:

A `rm -rf <path>` will not prompt again, if you really want to delete the `<path>`.

### /bin/mv

Renaming or moving files can be archieved with `mv`


```bash
$ touch test.txt
$ ls 
test.txt
$ mv test.txt test2.txt
$ ls
test2.txt
```

| parameter                 | description                    |
| ------------------------- | ------------------------------ |
| `-f`, `--force`           | do not prompt before overwrite |
| `-n`, `--no-clobber`      | do not override existing files |
| `-v`, `--verbose`         | explain what is beeing done    |

### /bin/pwd

Gets the current directory

```bash
machine@user /bin $ pwd
/bin
```

### /bin/rmdir

When you want to remove empty directories, you can 

```bash
$ mkdir -p one/two/tree
$ ls -R
.:
one

./one:
two

./one/two:
tree

./one/two/tree:

$ rmdir -p one/two/tree/
$ ls -R
.:
```

| parameter                | description                        |
| ------------------------ | ---------------------------------- |
| `-p`, `--parents`        | delete parents, if they are empty  |

### /bin/sleep

When you want to have a controlled delay in your scripts you can

```bash
$ sleep 5
```

to make the current process sleep for five seconds.
You may also add a prefix

* `s` - seconds
* `m` - minutes
* `h` - hours
* `d` - days

## user command binaries

### /usr/bin/base64

When you want to do stuff with base 64 encoding `base64` is the right tool for this.

```bash
$ echo "test" | base64 
dGVzdAo=
$ echo "dGVzdAo=" | base64 -d
test
```

| parameter        | description |
| ---------------- | ----------- |
| `-d`, `--decode` | decode data |

### /usr/bin/basename

To get a basename for a file you can

```bash
/tmp$ touch test.txt
/tmp$ basename test.txt 
test.txt
/tmp$ basename test.txt .txt
test
```

The second parameter is a suffix, which will be removed as well

<!--
### /usr/bin/cut
### /usr/bin/dirname
### /usr/bin/du
### /usr/bin/env
### /usr/bin/expand
### /usr/bin/expr
### /usr/bin/factor
### /usr/bin/groups
### /usr/bin/head
### /usr/bin/logname
### /usr/bin/md5sum
### /usr/bin/nice
### /usr/bin/nl
### /usr/bin/nohup
### /usr/bin/nproc
### /usr/bin/numfmt
### /usr/bin/pinky
### /usr/bin/printenv
### /usr/bin/printf
### /usr/bin/realpath
### /usr/bin/seq
### /usr/bin/sha1sum
### /usr/bin/sha224sum
### /usr/bin/sha256sum
### /usr/bin/sha384sum
### /usr/bin/sha512sum
### /usr/bin/shred
### /usr/bin/shuf
### /usr/bin/sort
### /usr/bin/stat
### /usr/bin/sum
### /usr/bin/tac
### /usr/bin/tail
### /usr/bin/tee
### /usr/bin/timeout
### /usr/bin/tr
### /usr/bin/truncate
### /usr/bin/tsort
### /usr/bin/tty
### /usr/bin/unexpand
### /usr/bin/uniq
### /usr/bin/unlink
### /usr/bin/users
### /usr/bin/wc
### /usr/bin/who
### /usr/bin/whoami
### /usr/bin/yes
-->

[coreutils]: https://www.gnu.org/software/coreutils/
