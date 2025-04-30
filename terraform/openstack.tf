terraform {
  required_version = ">= 1.11.2"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "3.0.0"
    }
  }
}

provider "openstack" {
  user_name   = var.os_user_name
  password    = var.os_password
  auth_url    = var.os_auth_url
  tenant_name = var.os_tenant_name
}

# --- Получаем существующую сеть по ID ---
data "openstack_networking_network_v2" "students_net" {
  id = "17eae9b6-2168-4a07-a0d3-66d5ad2a9f0e"
}

# --- Берём стандартную security group по имени "default" ---
data "openstack_networking_secgroup_v2" "default_sg" {
  name = "default"
}

# --- Создаём свою security group и правило SSH ---
resource "openstack_networking_secgroup_v2" "savenko_group" {
  name        = "savenko-group"
  description = "SSH access for savenko-instance"
}

resource "openstack_networking_secgroup_rule_v2" "savenko_group_ssh" {
  security_group_id = openstack_networking_secgroup_v2.savenko_group.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- Создаём порт и прикрепляем к нему SG ---
resource "openstack_networking_port_v2" "server_port" {
  name       = "savenko-instance-port"
  network_id = data.openstack_networking_network_v2.students_net.id

  # Привязываем и default, и нашу группу
  security_groups = [
    data.openstack_networking_secgroup_v2.default_sg.id,
    openstack_networking_secgroup_v2.savenko_group.id,
  ]
}

# --- Создаём инстанс, используя порт ---
resource "openstack_compute_instance_v2" "savenko_server" {
  name              = "savenko-instance-01-trf"
  flavor_name       = "m1.small"
  image_id          = "d608627a-ef62-452d-8a74-1c307cbe276d"  # ubuntu 22.04
  availability_zone = "nova"
  key_pair          = "savenko1"

  network {
    port = openstack_networking_port_v2.server_port.id
  }

  # Чтобы не было гонки с SG, явно указываем зависимость
  depends_on = [
    openstack_networking_secgroup_v2.savenko_group,
  ]
}

# --- Выводим IP для доступа и Ansible ---
output "server_ip" {
  description = "IPv4 address of savenko-instance-01"
  value       = openstack_compute_instance_v2.savenko_server.access_ip_v4
}

# --- Ждём, пока SSH сервис станет доступным ---
resource "null_resource" "wait_for_ssh" {
  depends_on = [openstack_compute_instance_v2.savenko_server]

  connection {
    type             = "ssh"
    user             = "ubuntu"
    host             = openstack_compute_instance_v2.savenko_server.access_ip_v4

    agent            = true              # используем ssh-agent
    agent_forwarding = true              # (опционально) проброс агента на VM
    timeout          = "5m"
  }

  provisioner "remote-exec" {
    inline = ["echo SSH is ready."]
  }
}

# --- Генерим динамический inventory для Ansible ---
resource "null_resource" "generate_inventory" {
  depends_on = [null_resource.wait_for_ssh]

  triggers = {
    server_ip = openstack_compute_instance_v2.savenko_server.access_ip_v4
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "[quizbot]" > hosts.ini
      echo "${openstack_compute_instance_v2.savenko_server.access_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/crplab-server" >> hosts.ini
    EOT
  }
}
