# Automatically update MIT licenses 

When you are using the MIT license for your own project, you can add copyright notices to the license.
The license starts with

```nohighlight
The MIT License (MIT)
Copyright (c) 2016 Jan Frederik Hake

Permission is hereby granted, free of charge, ...
```

For every year, you make changes to the source, you have to add the year to the copyright notice.
Especially for projects, which are rarely updated, the license is often forgotten.

With some git and awk magic, this task can be automated.
<!--more-->

# git log

I take my blog sources as an example.
The source for my changes is my git log.

If I like to see only the commit date and the name of the committer you can start with

```
$ git log --pretty=format:"%ad|%an" | head -n5
Wed Jun 28 19:00:52 2017 +0200|Jan Frederik Hake
Sat May 6 10:38:58 2017 +0200|Jan Frederik Hake
Sat May 6 10:29:15 2017 +0200|Jan Frederik Hake
Sat May 6 07:53:10 2017 +0200|Jan Frederik Hake
Thu May 4 11:57:25 2017 +0200|Jan Frederik Hake
```
   
I choose the pipe character as a separator for further processing.
The date can be formatted with the `--date` parameter.

    $ git log --pretty=format:"%ad|%an" --date=format:%Y | head -n 5
    2017|Jan Frederik Hake
    2017|Jan Frederik Hake
    2017|Jan Frederik Hake
    2017|Jan Frederik Hake
    2017|Jan Frederik Hake

In the next step I do some `uniq` and `sort` on the result. 
For the next process step, I switch the year and the name.

    $ git log --pretty=format:"%an|%ad"                  \
    >            --date=format:%Y | sort | uniq |        \
    >    awk 'BEGIN {FS="|"}                             \
    >    {                                               \
    >      if ($1==currentName) {                        \
    >              year=year "," $2;                     \
    >      }                                             \
    >      else {                                        \
    >          if (currentName) {                        \
    >              print "(c) " year " " currentName;    \
    >          };                                        \
    >          currentName=$1;                           \
    >          year=$2;                                  \
    >      }                                             \
    >    }                                               \
    >    END {                                           \
    >        if (currentName) {                          \
    >            print "(c) " year " " currentName;      \
    >        }                                           \
    >    }' 
    (c) 2016,2017 Jan Frederik Hake 

With a simple bash script you can update your LICENSE file of your project, if needed.

    #!/bin/sh
    if [ ! -f LICENSE ]; then
        break; 
    fi
    
    copyright=$(git log --pretty=format:"%an|%ad"       \
                --date=format:%Y | sort | uniq |        \
        awk 'BEGIN {FS="|"}                             \
        {                                               \
          if ($1==currentName) {                        \
                  year=year "," $2;                     \
          }                                             \
          else {                                        \
              if (currentName) {                        \
                  print "(c) " year " " currentName;    \
              };                                        \
              currentName=$1;                           \
              year=$2;                                  \
          }                                             \
        }                                               \
        END {                                           \
            if (currentName) {                          \
                print "(c) " year " " currentName;      \
            }                                           \
        }')
    
    license=$(cat LICENSE | sed -e "s/(c).*$/$copyright/g")
    echo "$license" > LICENSE

If you add the script to the project Makefile, there is no need for manually updating the LICENSE file any more.
