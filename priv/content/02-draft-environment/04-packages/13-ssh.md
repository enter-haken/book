# ssh

Connecting to a remote host

<!--host-->

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

| distribution | package name       |
| ------------ | ------------------ |
| ubuntu       | `openssh-client`   |
| gentoo       | `net-misc/openssh` |


