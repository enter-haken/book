# book 

These are the sources for [hake.one][1]

## requirements

For the build process the following is needed (at the time of writing)

* NodeJS: ~> 12.2.0
* elixir: ~> 1.9.4
* graphviz ~> 2.40.1

## build

To build the application you can call

```
$ make
```

When you want to run the application you can start the application with

```
$ make run
```

You can now see the website at `http://localhost:4040`.

```
$ make release
```

will build a release version of the application (using `mix release`)

When you start the application with 

```
$ _build/prod/rel/book/bin/book start
```

You can watch the result at `http://localhost:4050`.

## docker

If you just want to try out this application, or you don't want to insrtall the dependencies you can run the application within a docker container.

```
$ make docker
```

will create the application within tree steps.

* build the site css (bulma based)
* build the release 
  * generate the content
  * copy static files to the output folder
  * bake the content into the binary
* copy the release into the target image

Now you can start the application with

```
$ make docker_run
```

The site will be available at `http://localhost:4040`

# Contact

Jan Frederik Hake, <jan_hake@gmx.de>. [@enter_haken](https://twitter.com/enter_haken) on Twitter.


[1]: https://hake.one
