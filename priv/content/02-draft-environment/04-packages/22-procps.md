# procps

This package contains a bunch of small tools, which are usefull when you work with the `/proc` filesystem.

<!--more-->

For example, if you want to delete all zombie processes on a system you can do something like

```bash
$ kill $(ps -A -ostat,ppid | awk '/[zZ]/ && !a[$2]++ {print $2}')
```

| distribution | package name    |
| ------------ | --------------- |
| ubuntu       | `procps`        |
