
To generate a new RSA modulus:
```
openssl genrsa -out mykey.pem 1024
openssl rsa -in mykey.pem -pubout > mykey.pub
openssl rsa -pubin -modulus -noout -in mykey.pub 
rm mykey.pem
rm mykey.pub
```
