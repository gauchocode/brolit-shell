FROM ubuntu:22.04

# Set environment variable for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y \
        borgbackup \
        python3-pip \
        jq \
        yq \
        whiptail \
        sshfs \
        curl \
        wget \
        git \
        sudo \
        vim \
        iproute2 \
        iputils-ping \
        openssh-server && \
    pip3 install borgmatic && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/borgmatic.d /root/.config/borg /run/sshd

# Copy brolit-shell files
COPY . /brolit-shell

# Set working directory
WORKDIR /brolit-shell

# Configure SSH
RUN echo 'root:root' | chpasswd && \
    sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Expose SSH port
EXPOSE 22

# Start SSH service and keep container running
CMD ["/usr/sbin/sshd", "-D"]
