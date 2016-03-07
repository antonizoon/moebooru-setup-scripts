Moebooru Deployment Scripts
===========================

These scripts were developed by the Bibliotheca Anonoma for deploying

## Cloud9

You can create your own free moebooru instance on cloud9 for testing with this script. It does shut down after a week, but you can just restart it.

Just create a new cloud9 instance, then use the script below to install it. It will install with rubinius + puma for extra performance.

```
chmod +x moebooru-c9.sh
./moebooru-c9.sh
```

## Debian

> **Tip:** This script also works in a minimal systemd-nspawn container.

Run the first script as root to install all the prerequisites:

```
# bash 1-moebooru-debian.sh
```

Run the second script as the `moebooru` user to install moebooru with either JRuby 9000 or Rubinius, whichever you prefer. (Don't run both).

```
# sudo -i -u moebooru
$ bash 2-moebooru-debian-rbx.sh # rubinius
$ bash 2-moebooru-debian-jruby.sh # or jruby
```

Finally, test out the server by running the following commands (go to `http://localhost:3000` to check out the site):

JRuby:

```
jruby -S bundle exec puma -p 3000
```

Rubinius

```
bundle exec puma -p 3000
```

## CentOS

> **Note:** Not finished yet.

## Docker

> **Note:** Not finished yet.