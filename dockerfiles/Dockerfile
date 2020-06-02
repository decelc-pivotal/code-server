FROM debian:10

RUN apt-get update

# Install misc build dependencies
RUN apt-get install -y curl git rsync unzip

# Install code-server
RUN curl -fOL https://github.com/cdr/code-server/releases/download/v3.4.0/code-server_3.4.0_amd64.deb
RUN dpkg -i code-server_3.4.0_amd64.deb
RUN rm code-server_3.4.0_amd64.deb

# Setup user
RUN adduser --gecos '' --disabled-password coder
RUN chown -Rh coder:coder /home/coder

# Install JDK
RUN apt-get install -y default-jdk

WORKDIR /home/coder

USER coder

EXPOSE 8080

ENTRYPOINT code-server --bind-addr 0.0.0.0:8080 .
