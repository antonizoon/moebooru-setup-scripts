#!/bin/bash
# Moebooru Quick Setup Script
# This script deploys a test system of Moebooru on Cloud9.
# Uses TCP Ports. Would have used UNIX sockets but couldn't figure out how to get them working, and those don't pass through a chroot anyway.

# Run as root. Make sure sudo is installed.

# config usernames

username="moebooru"
userpass="password"
sitename="Moebooru"
hostname="eikonos.org" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

# get a copy of moebooru and give everyone the correct permissions
function git_clone() {
    # install git
    apt-key update # new keys needed in brand new nspawn container
    apt-get update
    apt-get install git curl
    
    # create working dir and git clone to it
    mkdir -p $workdir
    git clone git://github.com/moebooru/moebooru $workdir

    # create the user that will run this system
    useradd $username -d $workdir -s /bin/bash -g www-data
    echo $username:$userpass | chpasswd
    
    # add users to www-data group
    usermod -a -G www-data www-data        # username may be nginx in debian
    usermod -a -G www-data $username
    
    # set www-data group as /var/www/ group. Since Cloud9 is incapable of changing groups, set ubuntu as owner
    chown -R $username /var/www/
    chgrp -R www-data,sudo /var/www/
    chmod -R 775 /var/www/
}

# install postgresql
function postgres_install() {
    echo ":: Installing PostgreSQL..."
    
    curl -sL 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" | tee /etc/apt/sources.list.d/postgres.list
    echo "deb-src http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" | tee --append /etc/apt/sources.list.d/postgres.list
    apt-get update
    apt-get -y install postgresql-9.4 postgresql-contrib-9.4 sudo
    
    # restart postgresql daemon
    systemctl start postgresql
    systemctl enable postgresql
}

function postgres_config() {
    echo ":: Configuring PostgreSQL..."
    
    # reconfigure database to use unicode
    sudo -u postgres psql -c "UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';"
    sudo -u postgres psql -c "DROP DATABASE template1;"
    sudo -u postgres psql -c "CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';"
    sudo -u postgres psql -c "UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';"
    
    # connect to the database and configure it with test_parser from postgresql-contrib
    sudo -u postgres psql -d template1 -c "CREATE extension test_parser;"
    sudo -u postgres psql -d template1 -c "VACUUM FREEZE;"
    
    # create postgresql database user for moebooru
    sudo -u postgres psql -d template1 -c "CREATE user $db_user WITH password '$db_password' CREATEDB;"
}

function nodejs_install() {
    echo ":: Installing NodeJS.."
    
    curl -sL https://deb.nodesource.com/setup | bash -
    apt-get -y install nodejs
}

# not used in our container since we already have nginx on the outside
function nginx_install() {
    echo ":: Installing Nginx..."
    
    echo "deb http://nginx.org/packages/mainline/debian/ jessie nginx" |    tee /etc/apt/sources.list.d/nginx.list
    echo "deb-src http://nginx.org/packages/mainline/debian/ jessie nginx" |    tee --append /etc/apt/sources.list.d/nginx.list
    curl -sL http://nginx.org/keys/nginx_signing.key | apt-key add -
    apt-get update
    apt-get install nginx
    
    # stop nginx service using upstart for cloud9
    service nginx stop
}

function nginx_config() {
    echo ":: Configuring Nginx..."
    # tips for centos: http://ruby-journal.com/how-to-setup-rails-app-with-puma-and-nginx/
    # Method 1: Use proxy_pass. Since it has to use the TCP Stack, this does add yet another layer, but it is fast enough.
    cat << 'EOF' | tee /etc/nginx/sites-available/moebooru
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
    systemctl restart nginx
    
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

# alternate method of installing rubinius using the binaries, would work container-wide. Only use if ruby has never been installed before.
function rubinius_binaries() {
    apt-get update
    apt-get install -y bzip2 libyaml-0-2 libssl1.0.0 clang-3.4 make
    cd /tmp && wget https://rubinius-binaries-rubinius-com.s3-us-west-2.amazonaws.com/ubuntu/14.04/x86_64/rubinius-3.19.tar.bz2
    cd /opt && tar -xvjf /tmp/rubinius-3.19.tar.bz2
    
    # make this rubinius version usable by everyone
    echo 'export PATH=/opt/rubinius/3.19/bin:/opt/rubinius/3.19/gems/bin:$PATH' | tee /etc/profile.d/rubinius.sh
}

## Main Function

# set up prerequisites
git_clone

postgres_install
postgres_config

#nginx_install
#nginx_config

nodejs_install
nodejs_config

# install rubinius
#rubinius_binaries

# inform user that setup is complete and tell them to run a command
echo ":: Setup script complete. (but check output for errors)"
echo ":: Make sure the postgresql services are started, or enabled at boot."
echo ":: First go to the /var/www/moebooru directory:"
echo "::     cd /var/www/moebooru"
echo ":: Run the following command to start the webserver for Moebooru:"
echo "::     bundle exec unicorn -D"
echo ":: Or for Rubinius Users, set rubinius as your ruby version, install all prerequisites, and then use Puma as the webserver:"
echo "::     rvm use rbx"
echo "::     bundle install"
echo "::     bundle exec puma -p 8081"
echo "::"
echo ":: Then go to http://<projectname>-<project>.c9users.io to view your site,"
echo ":: Or just click **Preview** on the Cloud9 toolbar."
echo ":: Note that the first user created on Moebooru becomes the admin."