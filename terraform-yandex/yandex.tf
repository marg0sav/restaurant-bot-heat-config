terraform {
  required_version = ">= 0.13"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.7"
    }
  }
}


#
# Провайдер
#
provider "yandex" {
  token     = var.yandex_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

#
# Сеть и подсеть
#
data "yandex_vpc_network" "default" {
  folder_id = var.folder_id
  name      = "default"
}

resource "yandex_vpc_subnet" "savenko_subnet" {
  name           = "savenko-subnet"
  zone           = var.zone
  network_id     = data.yandex_vpc_network.default.id
  v4_cidr_blocks = ["192.168.30.0/24"]
}


#
# Security group + правило SSH
#
resource "yandex_vpc_security_group" "savenko_sg" {
  name       = "savenko-sg"
  network_id = data.yandex_vpc_network.default.id
}

resource "yandex_vpc_security_group_rule" "savenko_allow_ssh" {
  security_group_binding = yandex_vpc_security_group.savenko_sg.id
  direction              = "ingress"
  description            = "Allow SSH for Savenko"
  v4_cidr_blocks         = ["0.0.0.0/0"]
  protocol               = "TCP"
  port                   = 22
}

#
# Диск
#
resource "yandex_compute_disk" "savenko_boot_disk" {
  name     = "savenko-boot-disk"
  type     = "network-hdd"
  zone     = var.zone
  size     = 20
  image_id = var.image_id
}

#
# Виртуальная машина
#
resource "yandex_compute_instance" "savenko_vm" {
  name = "savenko-vm"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.savenko_boot_disk.id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.savenko_subnet.id
    nat                = true
    security_group_ids = [ yandex_vpc_security_group.savenko_sg.id ]
  }

  # Добавляем SSH-ключ для пользователя ubuntu
  metadata = {
    ssh-keys = "ubuntu:${chomp(file(var.ssh_public_key_path))}"
  }
}

# Добавляем провайдер time для фиксации момента запуска
resource "time_static" "now" {}

# Генерация динамического inventory для Ansible
resource "null_resource" "generate_inventory" {
  # Зависим от создания ВМ и фиксации времени
  depends_on = [
    yandex_compute_instance.savenko_vm,
    time_static.now,
  ]

  # Чтобы при каждом плане с новым time_static.now.id перегенерить файл
  triggers = {
    server_ip = yandex_compute_instance.savenko_vm.network_interface.0.nat_ip_address
    run_id    = time_static.now.id
  }

  provisioner "local-exec" {
    # команда, создающая hosts.ini
    command = <<EOT
      echo "[restaurantbot]" > hosts.ini
      echo "${yandex_compute_instance.savenko_vm.network_interface.0.nat_ip_address}" >> hosts.ini
    EOT
  }
}
