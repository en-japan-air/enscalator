# Using easy-rsa for PKI

PKI for self-signed certificates is necessary for secure
configuration of OpenVPN server and corresponding clients.

Build docker container with easy-rsa

```
$ cd tools
$ docker build -t easyrsa .
```

## Create new root certificate

Run docker `easyrsa` mounting directory for storing generated keys/certs

```
$ docker run -it --rm -v $PWD/keys:/etc/openvpn/easy-rsa/keys easyrsa /bin/bash
```

Genereate new root ca certificate

```
$ touch ./keys/index.txt
$ echo 01 > ./keys/serial
$ ./build-dh
$ ./pkitool --initca
```

> Warning: be careful with commands above. If directory `keys` is not empty
> already generated keys/certs will be overridden.

## Create server certificate

Generate new server certificate based on existing root ca certificate

```
$ ./pkitool --server server
$ cd keys && openvpn --genkey --secret ta.key && cd ..
```

## Create client certificate(s)

It is recommended to generate new certificate for each client (for example `user6ecef2d4`).

```
$ KEY_EMAIL="user6ecef2d4@en-japan.io" ./pkitool user6ecef2d4
```

or with password protection enabled

```
$ KEY_EMAIL="user6ecef2d4@en-japan.io" ./pkitool --pass user6ecef2d4
```

## Revoke client certificate

Provide client username for which you'd like to revoke certificate

```
$ ./revoke-full user6ecef2d4
```

## Reference

For additional reading and insights into OpenVPN configuration, 
please refer to the [official documentation](https://openvpn.net/index.php/open-source/documentation/howto.html).

# Sample OpenVPN client configuration

```
client
dev tun
proto udp
remote <Gateway ip address or Hostname> 1194

resolv-retry infinite
nobind
persist-key
persist-tun
mtu-test

ca ca.crt
cert user6ecef2d4.crt
key user6ecef2d4.key
tls-auth ta.key 1

comp-lzo
verb 3
```
