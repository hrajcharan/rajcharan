#!/bin/bash

# week-05 sample code to install Nginx webserver

sudo apt update
sudo apt install -y nginx

# Enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx