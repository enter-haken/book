# server

When you are running a server on the internet, it does not take a long time, until the first login attempts occurs.

```nohighlight
...
Jan 12 07:31:39 zeus sshd[22519]: Invalid user 0 from 45.136.108.85 port 20346
Jan 12 07:31:40 zeus sshd[22519]: Disconnecting invalid user 0 45.136.108.85 port 20346: Change of username or service not allowed: (0,ssh-connection) -> (22,ssh-connection) [preauth]
Jan 12 07:31:42 zeus sshd[22522]: Invalid user 22 from 45.136.108.85 port 56980
Jan 12 07:31:44 zeus sshd[22522]: Disconnecting invalid user 22 45.136.108.85 port 56980: Change of username or service not allowed: (22,ssh-connection) -> (101,ssh-connection) [preauth]
Jan 12 07:31:50 zeus sshd[22524]: Invalid user 101 from 45.136.108.85 port 48540
Jan 12 07:31:51 zeus sshd[22524]: Disconnecting invalid user 101 45.136.108.85 port 48540: Change of username or service not allowed: (101,ssh-connection) -> (123,ssh-connection) [preauth]
Jan 12 07:31:53 zeus sshd[22526]: Invalid user 123 from 45.136.108.85 port 48229
Jan 12 07:31:53 zeus sshd[22526]: Disconnecting invalid user 123 45.136.108.85 port 48229: Change of username or service not allowed: (123,ssh-connection) -> (1111,ssh-connection) [preauth]
Jan 12 07:32:00 zeus sshd[22528]: Invalid user 1111 from 45.136.108.85 port 25894
Jan 12 07:32:01 zeus sshd[22528]: Disconnecting invalid user 1111 45.136.108.85 port 25894: Change of username or service not allowed: (1111,ssh-connection) -> (1234,ssh-connection) [preauth]
...
```

This is where `fail2ban` comes into play. 
With a `/etc/fail2bain/jail.local` config.

```
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
```

Configuring a firewall can be a messy thing. 
On a linux system, you can use [netfilter][1]. 
This is the most basic part of the firewall, wich comunicates with the kernel.
Most users will use [iptables][2], but the configuration is still errorprone.


```{lang=dot}
digraph {
    rankdir=LR;

    node [fontname="helvetica",style="filled,rounded",color=lightgrey,shape=box];
    graph [fontname="helvetica"];
    edge [fontname="helvetica"];

    style=filled;
    color=lightgrey;

    netfilter -> iptables -> ufw;
}
```

# nginx

If you want to [use ssl with nginx][3] you can use your own certificates or use letsencrypt.

Seting up letsencrypt only needed a few steps.
First of all, you need to create a certbot repository.

```
$ add-apt-repository ppa:certbot/certbot
```


then install certbot itself

```
$ apt-get update
$ apt-get install python-certbot-nginx
```

Now you can obtain certificates for your domain.
It will be checked, if provided domains are valid.


```
$ sudo certbot --nginx -d hake.one -d retro.hake.one
```

After obtaining your certificates, you can take a look at your server configs 
under `/etc/nginx/sites-available/`, where certbot has added some extra configurations.

The cool thing here is, that certbot has detected different subdomain configs, so you 
don't need to tweak your config.

After reloading your nginx configuration, all your sites are ssl encrypted for the next 90 days.


[1]: https://en.wikipedia.org/wiki/Netfilter
[2]: https://en.wikipedia.org/wiki/Iptables
[3]: https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/ 
