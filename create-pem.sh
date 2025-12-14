mkdir -p ./certs
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=NA/ST=NA/L=NA/O=NA/CN=Generic SSL Certificate" -keyout ./certs/privkey.pem -out ./certs/fullchain.pem