[Youtube](https://youtu.be/U6YIwta8zw0?si=YIqNhtHPZQYOcNgi)

# Nested virtualization

```
sudo sh -c "echo 'options kvm-amd nested=1' >> /etc/modprobe.d/dist.conf"
sudo modprobe kvm-amd
cat /sys/module/kvm_amd/parameters/nested
```

# Devstack install

```
sudo useradd -s /bin/bash -d /opt/stack -m stack
sudo chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo -u stack -i
git clone https://opendev.org/openstack/devstack
cd devstack
wget https://raw.githubusercontent.com/filip-lebiecki/devstack/refs/heads/main/local.conf
./stack.sh
```

# Terraform

```
wget https://raw.githubusercontent.com/filip-lebiecki/devstack/refs/heads/main/main.tf
terraform init
terraform apply
```
