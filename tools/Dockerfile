FROM debian:8.1

MAINTAINER Denis Vazhenin <denis.vazhenin@en-japan.io>

# Path where easy-rsa certificates gets created
ENV EASY_RSA_DIR /etc/openvpn/easy-rsa
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install openvpn -y && \
    mkdir -p $EASY_RSA_DIR && \
    cp -R /usr/share/easy-rsa/* $EASY_RSA_DIR/ && \
    chown -R root:root $EASY_RSA_DIR && \
    chmod -R g+w $EASY_RSA_DIR && \
	echo "source $EASY_RSA_DIR/vars" >> /root/.bashrc

# Add certificate parameters
ADD vars $EASY_RSA_DIR/vars

# Change default directory to be $EASY_RSA_DIR
WORKDIR $EASY_RSA_DIR

VOLUME "/etc/openvpn/easy-rsa/keys"

