# Dockerfile for Rubinius and PostgreSQL Persistent
# Merges three dockerfiles:
# https://www.andreagrandi.it/2015/02/21/how-to-create-a-docker-image-for-postgresql-and-persist-data/
# https://github.com/rubinius/docker/blob/master/ubuntu/14.04/Dockerfile
# https://github.com/dockerfile/nginx/blob/master/Dockerfile
FROM ubuntu:14.04
MAINTAINER Antonizoon <antonizoon@bibanon.org>

# set UTF-8 Locale
RUN locale-gen en_US.UTF-8
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

## install node.js for moebooru
RUN curl -sL https://deb.nodesource.com/setup | sudo bash -
RUN apt-get update && apt-get -y install nodejs

# install rubinius prerequisites
RUN apt-get update && apt-get install -y \
        bzip2 \
        libyaml-0-2 \
        libssl1.0.0 \
        clang-3.4 \
        make

# get rubinius binaries and put in /opt/
ADD https://rubinius-binaries-rubinius-com.s3-us-west-2.amazonaws.com/ubuntu/14.04/x86_64/rubinius-3.19.tar.bz2 /tmp/rubinius.tar.bz2
RUN cd /opt && tar xvjf /tmp/rubinius.tar.bz2

# set global path for rubinius binaries
ENV PATH /opt/rubinius/3.19/bin:/opt/rubinius/3.19/gems/bin:$PATH

# add postgresql repo and keys
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# install postgresql
RUN apt-get update && apt-get -y -q install python-software-properties software-properties-common \
    && apt-get -y -q install postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4

## start postgresql with postgres user
USER postgres
RUN /etc/init.d/postgresql start \
    && psql --command "CREATE USER pguser WITH SUPERUSER PASSWORD 'pguser';" \
    && createdb -O pguser pgdb

## complete configuration of postgresql as root
USER root
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.4/main/postgresql.conf

# expose the postgresql port
EXPOSE 5432

# create postgresql shared folders
RUN mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

## switch to postgresql user, and set postgresql server to run by default
USER postgres
CMD ["/usr/lib/postgresql/9.4/bin/postgres", "-D", "/var/lib/postgresql/9.4/main", "-c", "config_file=/etc/postgresql/9.4/main/postgresql.conf"]

## create an unprivileged Moebooru user, and an nginx user
USER root
RUN useradd -m moebooru
RUN chsh -s /bin/bash moebooru
RUN usermod -G moebooru,www-data moebooru
RUN usermod -a -G www-data www-data        # username may be nginx in debian

# create /var/www/moebooru directory with www-data group and git clone
RUN mkdir -p /var/www/moebooru
RUN apt-get install -y wget git-core
RUN git clone git://github.com/moebooru/moebooru /var/www/moebooru

RUN chown -R moebooru /var/www/
RUN chgrp -R www-data /var/www/
RUN chmod -R 775 /var/www/

## complete with starting up moebooru user
USER moebooru
CMD ["bash"]