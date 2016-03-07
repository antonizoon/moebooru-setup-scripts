#!/bin/bash
# Moebooru PostgreSQL configurator
# Run as postgresql user

# config usernames

username="moebooru"
sitename="Moebooru"
hostname="moebooru-penultimate-iruel.c9users.io" # <projectname>-<username>.c9users.io  This must be changed to your correct domain or users won't be able to log in! 
db_user="moe"
db_password="imouto"    # change this before using the script!

workdir="/var/www/moebooru"   # in production, www-data must control the files

function postgres_config() {
    echo ":: Configuring PostgreSQL..."
    
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

# Main function
postgres_config