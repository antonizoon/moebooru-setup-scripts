#!/bin/bash
# Moebooru Dependency Installer
# Installs all dependencies as root. May not be needed thanks to the dockerfile, but who knows.

# config usernames

username="moebooru"
sitename="Moebooru"
hostname="moebooru-penultimate-iruel.c9users.io" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

# get a copy of moebooru and give everyfone the correct permissions
function git_clone() {
    mkdir -p $workdir
    git clone git://github.com/moebooru/moebooru $workdir

    # add users to www-data group
    usermod -a -G www-data www-data        # username may be nginx in debian
    usermod -a -G www-data $username
    
    # set www-data group as /var/www/ group. Since Cloud9 is incapable of changing groups, set ubuntu as owner
    chown -R $username /var/www/
    chgrp -R www-data /var/www/
    chmod -R 775 /var/www/
}

# install postgresql
function postgres_install() {
    echo ":: Installing PostgreSQL..."
    
    curl -sL 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' |    apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" |    tee /etc/apt/sources.list.d/postgres.list
    echo "deb-src http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" |    tee --append /etc/apt/sources.list.d/postgres.list
    apt-get update
    apt-get -y --purge autoremove postgresql* # delete old version of psql
    apt-get -y install postgresql-9.5 postgresql-contrib-9.5
    
    # restart postgresql daemon
    service postgresql restart
}

function nodejs_install() {
    echo ":: Installing NodeJS.."
    
    curl -sL https://deb.nodesource.com/setup |    bash -
    apt-get -y install nodejs
}

# not used in cloud9
function nginx_install() {
    echo ":: Installing Nginx..."
    
    echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" |    tee /etc/apt/sources.list.d/nginx.list
    echo "deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx" |    tee --append /etc/apt/sources.list.d/nginx.list
    curl -sL http://nginx.org/keys/nginx_signing.key |    apt-key add -
    apt-get update
    apt-get install nginx
    
    # stop nginx service using upstart for cloud9
    service nginx stop
}

function nginx_config() {
    echo ":: Configuring Nginx..."
    # tips for centos: http://ruby-journal.com/how-to-setup-rails-app-with-puma-and-nginx/
    # Method 1: Use proxy_pass. Since it has to use the TCP Stack, this does add yet another layer, but it is fast enough.
    cat << 'EOF' |    tee /etc/nginx/sites-available/moebooru
server {
    listen 8080;
    server_name moebooru-proxy-iruel.c9users.io;
    location / {
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      # Fix the "It appears that your reverse proxy set up is broken" error.
      proxy_pass http://127.0.0.1:8081;
      proxy_read_timeout 90;
      proxy_redirect http://127.0.0.1:8081 https://moebooru-proxy-iruel.c9users.io;
    }
}
EOF
    # enable moebooru config and disable default config
    rm /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/moebooru /etc/nginx/sites-enabled/moebooru
    
    # restart Nginx 
    service nginx restart
    
    # if using puma with Nginx, use a unix sock instead of standard proxy pass, for better performance
    # http://stackoverflow.com/questions/17450672/how-to-start-puma-with-unix-socket/17451342#17451342
    # bundle exec puma -e production -d -b unix:///var/run/my_app.sock
    
    # Alternatively, create a puma file directly and have puma check it on command execution:
    # http://nicolas-brousse.github.io/ubuntu-install-and-tips/pages/installation/rails-puma/
    # bundle exec puma --config config/puma.rb
}

function moebooru_depends() {
    echo ":: Installing Moebooru Dependencies..."
    
    apt-get -y install build-essential libxml2-dev libxslt1-dev libpq-dev git jhead libgd2-noxpm-dev imagemagick
}

## Main Function

# set up prerequisites as root
git_clone

nginx_install
nginx_config

nodejs_install
nodejs_config

postgres_install
moebooru_depends