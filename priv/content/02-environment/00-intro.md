# environment 

Before you start creating software, you need a solid working environment.
Nowadays many of the software out there is running on linux based systems.
Your software should be developed on the target plattform.
It is important, to get used to the system you are targeting over time.

## linux

There are several linux distributions out there. 
Some of them are targeting server systems like `centos`,
others are targeting workinstations like `ubuntu` or `gentoo`.
The goal is, to have a distribution indepent environment.

## GNU coreutils

The `GNU coreutils` consists of a brunch of base commands, which will be used on a daily basis.
I introduce some of these commands with small examples and usages.

## packages 

Packages can consist of multiple commands, and often have own configuration files. 
This is a overview of usefull packages and their configuration.

## vim

The heart of every developers toolchain is the editor.
You can choose, what ever you like. 
When you are developing a java or .net based system, you may be better of using a full blown IDE.
But this is not neccessary every time.
I want to show you, how far you can get, using `vim` as you primary editor.

## dotfiles

After packages are installed you can configure a package on system level within the `/etc` folder.
Many packages provide a local profile, which can be configured on a user basis. 
These called [dotfiles](/environment/dotfiles) should be configured in one place.
This is [how we do it](/environment/dotfiles/script.html).

## setup

Every time you set up a new machine or start working for a new employer, you might want to have your well known setup.
Mostly, you won't able to change your computer setup, because this is handled by you IT department.
It is still possible to bring your setup up and running on almost every system you can find.
