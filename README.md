## Self-Signed Certificate
```bash
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out cert.crt -keyout cert.key
```