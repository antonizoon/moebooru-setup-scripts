#!/bin/bash
# Moebooru Quick Setup Script
# This script deploys a test system of Moebooru on Cloud9.
# Uses Nginx Proxy Pass. Would have used UNIX sockets but couldn't figure out how to get them working.

# Note: sudo is often used because the script must be able to switch between root user and current user at will

# config usernames

username="ubuntu"
sitename="Moebooru"
hostname="moebooru-penultimate-iruel.c9users.io" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

# get a copy of moebooru and give everyone the correct permissions
function git_clone() {
    sudo mkdir -p $workdir
    sudo git clone git://github.com/moebooru/moebooru $workdir

    # add users to www-data group
    sudo usermod -a -G www-data www-data        # username may be nginx in debian
    sudo usermod -a -G www-data $username
    
    # set www-data group as /var/www/ group. Since Cloud9 is incapable of changing groups, set ubuntu as owner
    sudo chown -R ubuntu /var/www/
    sudo chgrp -R www-data /var/www/
    sudo chmod -R 775 /var/www/
}

# install rvm: https://www.digitalocean.com/community/tutorials/how-to-install-ruby-on-rails-on-ubuntu-14-04-using-rvm
function rvm_install() {
    # get rvm gpg signing key
    gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
    
    # run the rvm installer script
    curl -sSL https://get.rvm.io | bash -s stable --rails
    
    # use rvm in user directory
    source ~/.rvm/scripts/rvm
}

# install rubinius: http://rayhightower.com/blog/2014/02/06/installing-rubinius-using-rvm/
function rubinius_install() {
    # refresh rvm repos
    rvm get head
    
    # install rubinius
    # if you have issues here with cloud9, cgroups-lite might not be configured correctly: http://askubuntu.com/questions/656357/upstart-conf-file-not-being-copied/656379#656379
    rvm install rbx
    
    # set rubinius as the default ruby version
    rvm --default use rbx
    rvm use rbx
    
    # display current ruby engine
    ruby -v
}

function puma_config() {
    # create required folders for unix sockets
    #mkdir -p "$workdir/shared/sockets"
    #mkdir -p "$workdir/shared/log"
    #mkdir -p "$workdir/shared/pid"
    
    # get number of processor cores
    cores=`grep -c processor /proc/cpuinfo`
    
    # write up config/puma.rb, custom puma settings
    
    # For centos you will need a systemd service rather than upstart
    # https://gist.github.com/velenux/6883dc221a7d2eae7dcb
    
}

# install postgresql
function postgres_install() {
    echo ":: Installing PostgreSQL..."
    
    sudo curl -sL 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' | sudo apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" | sudo tee /etc/apt/sources.list.d/postgres.list
    echo "deb-src http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" | sudo tee --append /etc/apt/sources.list.d/postgres.list
    sudo apt-get update
    sudo apt-get -y --purge autoremove postgresql* # delete old version of psql
    sudo apt-get -y install postgresql-9.5 postgresql-contrib-9.5
}

function postgres_config() {
    echo ":: Configuring PostgreSQL..."
    
    # restart postgresql daemon
    sudo service postgresql restart
    
    # reconfigure database to use unicode
    # double sudos to beat cloud9 postgres user lock (since we don't know cloud9 ubuntu user password and we should never set a password for user postgres)
    sudo sudo -u postgres psql -c "UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';"
    sudo sudo -u postgres psql -c "DROP DATABASE template1;"
    sudo sudo -u postgres psql -c "CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';"
    sudo sudo -u postgres psql -c "UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';"
    
    # connect to the database and configure it with test_parser from postgresql-contrib
    sudo sudo -u postgres psql -d template1 -c "CREATE extension test_parser;"
    sudo sudo -u postgres psql -d template1 -c "VACUUM FREEZE;"
    
    # create postgresql database user for moebooru
    sudo sudo -u postgres psql -d template1 -c "CREATE user $db_user WITH password '$db_password' CREATEDB;"
}

function nodejs_install() {
    echo ":: Installing NodeJS.."
    
    sudo curl -sL https://deb.nodesource.com/setup | sudo bash -
    sudo apt-get -y install nodejs
}

# not used in cloud9
function nginx_install() {
    echo ":: Installing Nginx..."
    
    echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
    echo "deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx" | sudo tee --append /etc/apt/sources.list.d/nginx.list
    sudo curl -sL http://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install nginx
    
    # stop nginx service using upstart for cloud9
    sudo service nginx stop
}

function nginx_config() {
    echo ":: Configuring Nginx..."
    # tips for centos: http://ruby-journal.com/how-to-setup-rails-app-with-puma-and-nginx/
    # Method 1: Use proxy_pass. Since it has to use the TCP Stack, this does add yet another layer, but it is fast enough.
    cat << 'EOF' | sudo tee /etc/nginx/sites-available/moebooru
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
    sudo rm /etc/nginx/sites-enabled/default
    sudo ln -s /etc/nginx/sites-available/moebooru /etc/nginx/sites-enabled/moebooru
    
    # restart Nginx 
    sudo service nginx restart
    
    # if using puma with Nginx, use a unix sock instead of standard proxy pass, for better performance
    # http://stackoverflow.com/questions/17450672/how-to-start-puma-with-unix-socket/17451342#17451342
    # bundle exec puma -e production -d -b unix:///var/run/my_app.sock
    
    # Alternatively, create a puma file directly and have puma check it on command execution:
    # http://nicolas-brousse.github.io/ubuntu-install-and-tips/pages/installation/rails-puma/
    # bundle exec puma --config config/puma.rb
}

function moebooru_setup() {
    echo ":: Setting up Moebooru..."
    
    sudo apt-get -y install build-essential libxml2-dev libxslt1-dev libpq-dev git jhead libgd2-noxpm-dev imagemagick
    #sudo gem install bundler  # bundler already installed on cloud9
    
    # go to the current working directory
    cd $workdir
    
    # create database.yml file with the stated database login info
    cp -f config/database.yml.example config/database.yml
    sed -i -e "s/moe$/$db_user/g" config/database.yml
    sed -i -e "s/imouto$/$db_password/g" config/database.yml
    
    # create local_config.rb with stated hostname
    cp -f config/local_config.rb.example config/local_config.rb
    sed -i -e "s/DAN_SITENAME/$sitename/g" config/local_config.rb
    sed -i -e "s/DAN_HOSTNAME/$hostname/g" config/local_config.rb
}

function moebooru_install() {
    # go to the current working directory
    cd $workdir
    
    # create the necessary directories
    mkdir -p public/data
    mkdir -p public/data/{avatars,frame,frame-preview,image,inline,jpeg,preview,sample,search
    
    # install all dependencies
    rvm use rbx
    ruby -v
    bundle install
    
    # uncomment CONFIG["secret_key_base"] and generate a secret key to insert, then delete the variable
    sed -i -e '/secret_key_base/s/^# //g' config/local_config.rb
    secret_key=`bundle exec rake secret`
    sed -i -e "s/value here/$secret_key/g" config/local_config.rb
    unset secret_key
    
    # install moebooru
    bundle exec rake db:create
    echo ":: Note: Ignore the following, it is not a problem: 'must be owner of extension plpgsql'"
    bundle exec rake db:reset
    bundle exec rake db:migrate
    bundle exec rake i18n:js:export
    bundle exec rake assets:precompile
}

## Main Function

# set up prerequisites
git_clone
rvm_install
rubinius_install

postgres_install
postgres_config

#nginx_install
nginx_config

nodejs_install
nodejs_config

# set up moebooru itself
moebooru_setup
moebooru_install

# inform user that setup is complete and tell them to run a command
echo ":: Setup script complete. (but check output for errors)"
echo ":: Make sure the postgresql and nginx services are started, or enabled at boot."
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