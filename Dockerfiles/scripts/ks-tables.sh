mysql -h 10.0.0.254 -u root -pladakh1 -e "CREATE DATABASE keystone;"
mysql -h 10.0.0.254 -u root -pladakh1 -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'ha1.endor.lab' \
                                          IDENTIFIED BY 'ladakh1';"
