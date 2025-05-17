terraform {
required_version = ">= 1.11.4"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0.0"
    }
  }
}

provider "openstack" {
  auth_url    = "http://192.168.81.0/identity"
  region      = "RegionOne"
  tenant_name = "filip"
  user_name   = "filip"
  password    = "password"
  domain_name = "Default"
}

data "openstack_images_image_v2" "ubuntu" {
  name = "ubuntu"
}

data "openstack_compute_flavor_v2" "small" {
  name = "m1.small"
}

data "openstack_networking_network_v2" "private" {
  name = "filip-net"
}

resource "openstack_networking_secgroup_v2" "caddy_secgroup_http" {
  name        = "caddy-secgroup-http"
  description = "Allow HTTP"
}

resource "openstack_networking_secgroup_v2" "caddy_secgroup_ssh" {
  name        = "caddy-secgroup-ssh"
  description = "Allow SSH"
}

resource "openstack_networking_secgroup_rule_v2" "allow_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.caddy_secgroup_http.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.caddy_secgroup_ssh.id
}

data "template_file" "caddy_user_data" {
  template = <<EOF
#!/bin/bash
echo "ubuntu:password" | chpasswd
sed -i 's/^Include.*//' /etc/ssh/sshd_config
sed -i 's/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
apt-get update
apt-get install -y caddy
mkdir -p /var/www/html
ip_addr=$(ip -4 -br a s dev ens3 | awk '{ print $3 }')
echo "Server IP: $ip_addr" > /var/www/html/index.html
cat <<EOF_CADDY > /etc/caddy/Caddyfile
:80 {
  root * /var/www/html
  file_server
}
EOF_CADDY
systemctl enable caddy
systemctl restart caddy
EOF
}

resource "openstack_networking_port_v2" "caddy_port" {
  name                = "caddy-port"
  network_id          = data.openstack_networking_network_v2.private.id
  admin_state_up      = true
  security_group_ids  = [openstack_networking_secgroup_v2.caddy_secgroup_http.id,openstack_networking_secgroup_v2.caddy_secgroup_ssh.id]
}

resource "openstack_compute_instance_v2" "caddy_vm" {
  name       = "ubuntu-caddy"
  image_id   = data.openstack_images_image_v2.ubuntu.id
  flavor_id  = data.openstack_compute_flavor_v2.small.id
  key_pair        = "filip-key"
  security_groups = [openstack_networking_secgroup_v2.caddy_secgroup_http.name, openstack_networking_secgroup_v2.caddy_secgroup_ssh.name]

  network {
    port = openstack_networking_port_v2.caddy_port.id
  }

  user_data = data.template_file.caddy_user_data.rendered
}

data "openstack_networking_network_v2" "ext_network" {
  name = "public"
}

data "openstack_networking_subnet_ids_v2" "ext_subnets" {
  network_id = data.openstack_networking_network_v2.ext_network.id
}

resource "openstack_networking_floatingip_v2" "fip" {
  pool       = data.openstack_networking_network_v2.ext_network.name
  subnet_ids = data.openstack_networking_subnet_ids_v2.ext_subnets.ids
}

resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  port_id     = openstack_networking_port_v2.caddy_port.id
}

output "caddy_public_ip" {
  value = openstack_networking_floatingip_v2.fip.address
}
