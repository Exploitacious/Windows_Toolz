#!/bin/bash

# Update your existing list of packages
echo "Updating package list..."
sudo apt update

# Install prerequisites
echo "Installing prerequisites..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

# Add Docker’s official GPG key
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker stable repository for Debian
echo "Setting up the Docker stable repository..."
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian buster stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package database with Docker packages from the newly added repo
echo "Updating package database with Docker packages..."
sudo apt update

# Install Docker
echo "Installing Docker..."
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Add your user to the Docker group
echo "Adding user to Docker group..."
sudo groupadd docker
sudo usermod -aG docker $USER

# Start Docker service
echo "Starting Docker service..."
sudo service docker start

# Verify Docker installation
echo "Verifying Docker installation..."
docker --version

echo "Docker installation completed successfully!"
echo "You may need to restart your terminal or log out and log back in to apply the group changes."

