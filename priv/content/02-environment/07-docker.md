# docker

Docker is a virtualization technology on the OS-level, so you don't need to create a virtual machine.
You can create `containers` where programms can run in an isolated environment. 
You share your current kernel with the container. 
Usually you run one process within a container.
You can find prebuild containers on [dockerhub][dockerhub], or you can build some for your own.

## usecases

Imagine you want to find out if a new package fits your needs, and you don't want to pollute your system with new dependencies.
If the new package does not work for you, you can simply delete the docker container and your system works as before. 
Otherwise you can install it to your system and add it to your daily stack.

If you have several applications on one physical machine up and running, and you want to have a kind of seperation,
you can run every application within its own `container`.

You can run containers on AWS services like [AWS Fargate][fargate], and let Amazon handle the underlying VMs for you.
This reduces the application complexity by far.

## first container

As a first quick start you can run an ubuntu environment by

```bash
$ docker run -it ubuntu
Unable to find image 'ubuntu:latest' locally
latest: Pulling from library/ubuntu
7ddbc47eeb70: Pull complete 
c1bbdc448b72: Pull complete 
8c3b70e39044: Pull complete 
45d437916d57: Pull complete 
Digest: sha256:6e9f67fa63b0323e9a1e587fd71c561ba48a034504fb804fd26fd8800039835d
Status: Downloaded newer image for ubuntu:latest
```

This creates a `docker image` for ubuntu, creates a `named container` and starts it after creation.

with [docker ps][dockerps] you can see you current running containers. 

```bash
$ docker ps 
CONTAINER ID        IMAGE     COMMAND       CREATED              STATUS              PORTS  NAMES
cd56f3da4066        ubuntu    "/bin/bash"   About a minute ago   Up About a minute          fervent_poitras
```

If you don't name your container, with `--name` a random string like `fervent_poitras` will be used.

If you exit the container with `logout`, the `docker ps` will be empty.
The `-a` parameter will show you all your containers.

```bash
docker ps -a | grep fervent_poitras
cd56f3da4066        ubuntu                       "/bin/bash"              36 minutes ago      Exited (0) 17 minutes ago   fervent_poitras
```

When you start the container again,

```bash
$ docker start fervent_poitras
```

you can [attach][dockerattach] to it again

```bash
$ docker attach fervent_poitras
root@cd56f3da4066:/#
```

You combine the last to steps with

```bash
$ docker start --attach fervent_poitras
root@cd56f3da4066:/#
```

If you want to [delte][dockerdelete] the `fervent_poitras` container, you have to stop it first, before deletion.

```bash
$ docker stop fervent_poitras
fervent_poitras
$ docker rm fervent_poitras
fervent_poitras
```

After this the `container` is beeing removed, but the image will still be there.

If you create a new container,

```bash
$ docker run -it ubuntu
$ docker ps -a | grep ubuntu
e1f96f9c9a29        ubuntu                       "/bin/bash"              About a minute ago   Exited (0) About a minute ago    gracious_kalam 
$ docker start -a gracious_kalam 
root@e1f96f9c9a29:/# 
```

Now you have a fresh container, to start over again.

You can also try out a different image like `gentoo/stage3-amd64` to try out a different distribution.

With `docker`, you have the posibility to check your environment with different distributions, 
without installing them seperately.

## Dockerfile

For a first try, the "on the fly" images are good start, but you can also build your own images.
These images are described with a [Dockerfile][dockerfile].


[dockerhub]: https://hub.docker.com/
[fargate]: https://aws.amazon.com/fargate/
[dockerps]: https://docs.docker.com/engine/reference/commandline/ps/
[dockerattach]: https://docs.docker.com/engine/reference/commandline/attach/
[dockerdelete]: https://docs.docker.com/engine/reference/commandline/rm/
[dockerfile]: https://docs.docker.com/engine/reference/builder/
