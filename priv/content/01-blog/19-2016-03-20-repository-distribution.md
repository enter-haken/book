# Repository ownership

Weeks ago my colleagues and I had a discussion about code ownership. Over years ownership may skip over to other developers e.g. due to job change. For a approximation you can start with the files, checked in to repository. I will use the [Angular.js](https://github.com/angular/angular.git) repository for demonstrations.

<!--more-->

First make a local clone.

```
$ git clone https://github.com/angular/angular.git
```

A list of files can be obtained by

```
git ls-tree --full-tree -r HEAD
```

The first 10 entries look like 

```
100644 blob 9b2abeb660ab6c38a2378afd3a2f31bbca10cac3    .bowerrc
100644 blob 8d1c3c310286f5569e9ae2d99a5b50320a177e36    .clang-format
100644 blob f1cc3ad329c5d5be1f19d75f27352ea695de0afc    .editorconfig
100644 blob b7ca95b5b77a91a2e1b6eaf80c2a4a52a99ec378    .gitattributes
100644 blob 5f639fc3384e36b91c6efd28cf60e168680ce9f7    .github/ISSUE_TEMPLATE.md
100644 blob 8d93de2e45f1e6bf146cefd8b18526b2d99aaa82    .github/PULL_REQUEST_TEMPLATE.md
100644 blob 8060eef4d4c04f1f7f1aa6a48e9aaf7dc5e12584    .gitignore
100644 blob ade65226e0aa7e8abed00fc326362982f792b262    .nvmrc
100644 blob f31ef0d7d6996c8e202380b7a6bdfcb3ed757267    .travis.yml
100644 blob 0eefaa57ce1dfc216428f5664b632ec324cf918e    CHANGELOG.md
```

This command will give you all the files in the repository. (sub repositories are not considered at this point).

If you want to see, what is happening in a specific file the `git log` command is your friend. Let's look at an example.

```
$ git log --since="4 weeks ago" CHANGELOG.md
```

will give you an overview over the last four weeks for a specific file.

```
commit c194f6695d3a00330ddfbefdc3ba393b0dce0dab
Author: Jeremy Elbourn <jelbourn@google.com>
Date:   Fri Mar 18 14:35:40 2016 -0700

chore: bump version to beta.11 w/ changelog

commit ea11b3f1f87afbf27d7cd9de87384d4963cd1965
Author: Evan Martin <martine@danga.com>
Date:   Thu Mar 17 15:01:44 2016 -0700

docs(changelog): update change log to beta.10
                         
commit aa43d2f87b9411eee9801d5d45f789f8c4161aa2
Author: Vikram Subramanian <viks@google.com>
Date:   Wed Mar 9 14:56:08 2016 -0800

docs(changelog): update change log to beta 9

commit 2830df4190e98d05bad396993776d31ba6efa6e2
Author: vsavkin <avix1000@gmail.com>
Date:   Wed Mar 2 11:32:38 2016 -0800
```

we will only need the committer names.

```
$ git log --format="%an"  --since="4 weeks ago" CHANGELOG.md
Jeremy Elbourn
Evan Martin
Vikram Subramanian
vsavkin
```

Now we take all committers, count their names and take the first in list.

```
$ git log --format="%an" CHANGELOG.md | sort | uniq -c | sort -rn | head -n 1
     10 Igor Minar
```

This statement is very simple. "Igor Minar made the most commits on the file CHANGELOG.md". There are several ways to get the name after the count. Here is one.

```
$ echo "     10 Igor Minar" | xargs -e | cut -d " " -f2-
Igor Minar
```

The `xargs -e` command eliminates the leading white spaces. Splitting after the first whitespace gets the name.

Now we are almost ready. Putting all the peaces together will lead us to.

```
#!/bin/bash
for file in ` git ls-tree --full-tree -r HEAD | awk '{ print $4}'`;
do
    git log --format="%an" $file | sort | uniq -c | sort -rn | head -n 1 | xargs -e | cut -d " " -f2-
done
```

This script prints for each file the name of the committer with the most commits. When you pipe the output of this script into `committers.log` you can get the "main committers" for the whole repository.

```
$ cat committers.log | sort | uniq -c | sort -rn | awk '$1 > 10 { print }'
    381 vsavkin
    194 Tim Blasi
    147 Tobias Bosch
    128 Jeff Cross
    93 kutyel
    82 Brian Ford
    59 Jason Teplitz
    49 Yegor Jbanov
    45 Misko Hevery
    42 Julie Ralph
    40 Igor Minar
    32 Victor Berchet
    29 Matias Niemelä
    24 Alex Eagle
    16 Pawel Kozlowski
    16 Alex Rickabaugh
    15 Peter Bacon Darwin
    15 Ian Riley
    11 yjbanov
    11 Marc Laval
```

The output gives you a hint, what is currently happening in the repository. 
It says nothing about the quality of the work of the committer. 
[Rewriting commits](https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History) is often use to have a slim commit history. 
Others leave the commits as they are. 
For an older repository it may be more interesting, what has happened e.g. in the last two years. 
With a few adjustments this can be achieved. 
See [git log --since](https://git-scm.com/docs/git-log) for more information. 
