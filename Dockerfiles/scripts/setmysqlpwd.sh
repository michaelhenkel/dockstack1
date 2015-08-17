for i in 1 2 3 
do
docker exec gal1 mysql -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'ha$i.endor.lab' IDENTIFIED BY 'ladakh1' WITH GRANT OPTION"
docker exec gal1 mysql -u root -proot -e "SET PASSWORD FOR 'root'@'ha$i.endor.lab' = PASSWORD('ladakh1');FLUSH PRIVILEGES;"
done
docker exec gal1 mysql -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'vip.endor.lab' IDENTIFIED BY 'ladakh1' WITH GRANT OPTION"
docker exec gal1 mysql -u root -proot -e "SET PASSWORD FOR 'root'@'vip.endor.lab' = PASSWORD('ladakh1');FLUSH PRIVILEGES;"
mysql -h vip -u root -pladakh1 -e 'SELECT @@wsrep_node_name;'
