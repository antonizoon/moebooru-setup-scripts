#!/bin/bash
# Moebooru Setup Script
# Run as the user that will be running the engine, such as moebooru

username="moebooru"
sitename="Moebooru"
hostname="moebooru-penultimate-iruel.c9users.io" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

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

# set up moebooru itself using moebooru user
rvm_install
rubinius_install
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