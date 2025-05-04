variable "yandex_token" {
  type        = string
  description = "YC OAuth-токен"
}

variable "cloud_id" {
  type        = string
  description = "ID облака"
}

variable "folder_id" {
  type        = string
  description = "ID каталога"
}

variable "zone" {
  type        = string
  description = "Зона, например ru-central1-a"
}

variable "image_id" {
  type        = string
  description = "ID образа в Marketplace"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Путь до публичного SSH-ключа"
}
