# Linux

Linux is an operation system, released on September 17, 1991 by Linus Torvalds.
If you want to install linux, you can [choose a distribution][distrowatch], which fits your needs.  When you are working for a company, it is often the case, that you can't change the operation system. 
So I will focus on the commands, which are most commonly present on every installation, or which can be easily installed by a package manager.
This will lead to a distribution independent environment.

<!--more-->

## Filesystem Hierarchy Standard

Almost everything on a linux system can be accessed via a file. 
These files should be placed within certain directories, defined in the [Filesystem Hierarchy Standard][fhs], which is managed by the [linux foundation][foundation].

This is a incomplete list of some base folders within a linux system.

| directory  | description                                                              |
| ---------- | ------------------------------------------------------------------------ |
| `/`        | filesystem root.                                                         |
| `/boot`    | boot loader, kernels, initrd. often as a own partition.                  |
| `/dev`     | all devices, like hard drives, cpus ect.                                 |
| `/proc`    | virtual file system, amongst other things displaying processes as files. |
| `/tmp`     | temporary files, which may be deleted after system reboot.               |
| `/etc`     | system-wide configuration files.                                         |
| `/home`    | user home directory, which has often an own mount point.                 |
| `/mnt`     | temporary mounted file systems like usb drives.                          |
| `/opt`     | optional software packages.                                              |
| `/root`    | root home directory.                                                     |
| `/sbin`    | system binaries like `init` or `ip`.                                     |
| `/bin`     | single user mode commands like `cp`, `ls` or `mv`.                       |
| `/usr`     | installation target for distribution packages.                           |
| `/var`     | files, which may change over time like log files.                        |

More or less all distributions out there will use these directories in a proper way.
Your development environment will be found in your `home` folder. 
Packages like `htop` will use the information from the `/proc` folder to show all running processes in a convinient way.

## distribution specific

From time to time, you might execute some tasks which are distribution specific. 
Hopefully, this is will stay a small list.
I will take it as small as possible.

### command belongs to which package?

#### ubuntu

```bash
$ dpkg -S /usr/bin/head
coreutils: /usr/bin/head
```

or try

```bash
$ command -v head | xargs dpkg -S 
coreutils: /usr/bin/head
```

#### gentoo

using the `app-portage/gentoolkit`

```bash
$ equery belongs /bin/head 
* Searching for /bin/head ... 
sys-apps/coreutils-8.31-r1 (/bin/head)
```

### list all commands for a package

#### ubuntu

```bash
$ dpkg -L coreutils | grep /usr/bin | head
/usr/bin
/usr/bin/[
/usr/bin/arch
/usr/bin/b2sum
/usr/bin/base32
/usr/bin/base64
/usr/bin/basename
/usr/bin/chcon
/usr/bin/cksum
/usr/bin/comm]
```

#### gentoo 

using the `app-portage/gentoolkit`

```bash
$ equery files coreutils -f cmd | head
/bin/basename
/bin/cat
/bin/chgrp
/bin/chmod
/bin/chown
/bin/chroot
/bin/cp
/bin/cut
/bin/date
/bin/dd
```


[foundation]: https://www.linuxfoundation.org/
[fhs]: https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html
[ranger]: /environment/tools/ranger.html
[distrowatch]: https://distrowatch.com/
[bash]: https://www.gnu.org/software/bash/
