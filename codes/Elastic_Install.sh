#! /bin/bash

##Script to install Elastic Stack on Ubuntu machine.


ELK_version="6.x"
server_address="SERVERIPADDRESS"  # change accordingly
nginx_port=5601
beat_port=5044
elasticsearch_port=9200
kibana_username="USERNAME"   # change accordingly


# Use Ubuntu default package manager in order to install JAVA 8
# Logstash6.3 encounter error during installation 05-12-2018
apt-get update
apt-get -y install default-jdk 
apt-get -y install openjdk-8-jre  
add-apt-repository -y ppa:webupd8team/java
apt-get -y install oracle-java8-installer

# Setting up Elasticsearch

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
apt-get -y install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/${ELK_version}/apt stable main" |  tee -a /etc/apt/sources.list.d/elastic-${ELK_version}.list
apt-get update
apt-get -y install elasticsearch
echo "network.host: localhost" >> /etc/elasticsearch/elasticsearch.yml
service elasticsearch restart

# Install kibana

apt-get update
apt-get -y install kibana
echo 'server.host: "localhost"' >> /etc/kibana/kibana.yml
service kibana start

# Because we configured Kibana to listen on localhost, 
# we must set up a reverse proxy to allow external access to it. 
# We will use Nginx for this purpose.
apt-get -y install nginx apache2-utils
htpasswd -c /etc/nginx/htpasswd.users ${kibana_username}
cat > /etc/nginx/sites-available/default << EOL
server {
        listen      80;
        server_name SERVERIP;
        return 301 https://;
}

server {
        listen                *:443 ;
        ssl on;
        ssl_certificate /etc/pki/tls/certs/logstash-forwarder.crt;
        ssl_certificate_key /etc/pki/tls/private/logstash-forwarder.key;
        server_name           SERVERIP;
        access_log            /var/log/nginx/kibana.access.log;
        error_log  /var/log/nginx/kibana.error.log;

location / {
        auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/htpasswd.users;
        proxy_pass http://localhost:5601;
}
}
EOL

service nginx restart


#Install Logstash
apt-get update
apt-get -y install logstash

##### Enable if SSL is needed
#Generate SSL Certificates
# Since we are going to use Filebeat to ship logs from our Client Servers to our ELK Server, 
# we need to create an SSL certificate and key pair. 
# The certificate is used by Filebeat to verify the identity of ELK Server. 
#mkdir -p /etc/pki/tls/certs
#mkdir /etc/pki/tls/private
#sed -i "230i subjectAltName = IP: ${server_address}" /etc/ssl/openssl.cnf
#cd /etc/pki/tls
#openssl req -config /etc/ssl/openssl.cnf -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout private/logstash-forwarder.key -out certs/logstash-forwarder.crt
#cd


#This specifies a beats input that will listen on tcp port 5044, 

cat > /etc/logstash/conf.d/02-beats-input.conf << EOL
 input {
  beats {
    port => 5044
#    ssl => true
#    ssl_certificate => "/etc/pki/tls/certs/logstash-forwarder.crt"
#    ssl_key => "/etc/pki/tls/private/logstash-forwarder.key"
    type => "Snort"
  }
}
EOL

# Pattern for parsing Snort Logs
cat > /etc/logstash/conf.d/11-snort-filter.conf << EOL
filter {
  if [type] == "Snort" {
    grok { match => { "message" => "\[\*\*\] \[%{GREEDYDATA:Signature}\] %{GREEDYDATA:SnortMessage} \[\*\*\]%{GREEDYDATA:Classification}\[Priority: %{NUMBER:priority:int}\] \n%{GREEDYDATA:snortDate} %{IP:SourceIP}:%{NUMBER:SourcePort:int} \-\> %{IP:DestinationIP}:%{NUMBER:DestinationPort:int}\n%{WORD:Protocol} TTL:%{NUMBER:TTL:int} TOS:%{BASE16NUM:TOS} ID:%{NUMBER:ID:int} IpLen:%{NUMBER:IpLen:int} %{GREEDYDATA:options}"}
#      remove_field => [ "message" ]
    }

    date {
      match => ["snortDate", "MM/dd-HH:mm:ss.SSSSSS"]
      target => "@timestamp"
      remove_field => ["snortDate"]
      timezone => "Europe/Amsterdam"
      locale => "en_US"
    }
    geoip{
      source=>"SourceIP"
    }
  }
}
EOL

# This output basically configures Logstash to store the beats data in Elasticsearch which is running at localhost:9200,
# in an index named after the beat used (filebeat, in our case).
cat > /etc/logstash/conf.d/30-elasticsearch-output.conf << EOL
output {
  if [type] == "Snort" {
    elasticsearch {
      hosts => ["localhost:9200"] 
      manage_template => false
      index => "snort-%{+YYYY.MM.dd}"
    }
  }
}
EOL

#sudo service logstash restart
#sudo update-rc.d logstash defaults 96 9

#................................ Changed 2018-07-05
#Following is the deprecated Beats dashboard for Kibana4
# Load kibana dashboards
#cd ~
#curl -L -O http://download.elastic.co/beats/dashboards/beats-dashboards-1.1.2.zip
#apt-get -y install unzip
#unzip beats-dashboards-*.zip
#cd beats-dashboards-*/
#./load.sh

#cd ~
#curl -O https://gist.githubusercontent.com/thisismitch/3429023e8438cc25b86c/raw/d8c479e2a1adcea8b1fe86570e42abab0f10f364/filebeat-index-template.json

#curl -XPUT 'http://localhost:9200/_template/filebeat?pretty' -d@filebeat-index-template.json
#...............................
echo "................................................"
java -version
service nginx restart
service elasticsearch restart
service kibana restart
service logstash restart
systemctl enable elasticsearch
systemctl enable logstash
systemctl enable kibana
