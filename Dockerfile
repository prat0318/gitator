FROM ubuntu:14.04
MAINTAINER Prateek Agarwal <prat0318@gmail.com>
RUN apt-get -qq update
RUN apt-get -qqy install ruby ruby-dev git make
RUN gem install sinatra
RUN gem install bundler
ADD ./gitator /root/gitator/
RUN ls /root
RUN cd /root/gitator; bundle install
EXPOSE 4567
WORKDIR /root/gitator
CMD ["bundle", "exec", "rackup", "-p", "4567"]
