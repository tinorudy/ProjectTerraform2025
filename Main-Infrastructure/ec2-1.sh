#!/bin/bash
sudo apt update
sudo apt install apache2 -y
sudo apt systemctl enable apache2
sudo apt systemctl start apache2
echo "<html><h1>Hello guys! welcome to my Tinorudy First Website, we sell African Books</h1><html>" > /var/www/html/index.html
