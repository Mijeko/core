FROM nginx:latest

RUN apt update
RUN apt install -y sudo

RUN sudo apt install -y vim
RUN sudo apt install -y make

WORKDIR /var/www/${PROJECT_NAME}