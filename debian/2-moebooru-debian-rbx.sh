#!/bin/bash
# Moebooru Setup for engine user
# run as the engine user

username="moebooru"
userpass="password"
sitename="Moebooru"
hostname="eikonos.org" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

# install rbenv to get rubinius (one method)
function rbenv_install() {
    cd ~
    git clone git://github.com/sstephenson/rbenv.git .rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
    echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
    git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    source ~/.bash_profile
    
    # set up rubinius
    rbenv install rbx-3.16
    rbenv global rbx-3.16
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
    # Use -- due to the following bug: http://stackoverflow.com/a/24810293
    rvm install rubinius --
    
    # set rubinius as the default ruby version
    rvm --default use rbx
    rvm use rbx
    
    # display current ruby engine
    ruby -v
}

function jruby_install() {
    # refresh rvm repos
    rvm get head
    
    # install rubinius
    # Use -- due to the following bug: http://stackoverflow.com/a/24810293
    rvm install jruby
    
    # set rubinius as the default ruby version
    rvm --default use jruby-9.0.3.0
    rvm use jruby
    
    # display current ruby engine
    jruby -S gem install bundler
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
    
    # run as engine running user
    
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
    echo ":: Installing Moebooru..."

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

# main function
rvm_install
rubinius_install
#jruby_install

# set up moebooru
moebooru_setup
moebooru_install
