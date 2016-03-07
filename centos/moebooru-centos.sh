#!/bin/bash
# Moebooru Quick Setup Script
# This script deploys a test system of Moebooru on Cloud9.
# Uses Nginx Proxy Pass. Would have used UNIX sockets but couldn't figure out how to get them working.

# Note: The script should be run as root.

# config usernames
username="moebooru"
sitename="Moebooru"
hostname="localhost" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

# get a copy of moebooru and give everyone the correct permissions
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

# https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-centos-7
function postgres_install() {
    echo ":: Installing PostgreSQL..."
    yum install postgresql-server postgresql-contrib
    
    # start postgresql daemon and enable at boot
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

function nginx_install() {
    # install epel to get nginx
    yum install epel-release
    yum install nginx
}

function nginx_config() {
    firewall-cmd --permanent --zone=public --add-service=http 
    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --reload
}

function nodejs_install() {
    # install epel to get nginx
    yum install epel-release
    yum install nodejs
}

function moebooru_depends() {
    # debian original
    #apt-get -y install build-essential libxml2-dev libxslt1-dev libpq-dev git jhead libgd2-noxpm-dev imagemagick
    yum install make automake gcc gcc-c++ kernel-devel libxml2 libxml2-devel libxslt libxslt-devel
}

function moebooru_setup() {
    echo ":: Setting up Moebooru..."
    
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

# https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-centos-7
#nginx_install
#nginx_config

# https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-a-centos-7-server
nodejs_install

# set up moebooru itself
moebooru_depends
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