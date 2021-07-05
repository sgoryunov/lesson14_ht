terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

variable "token" {
  type = string
}

locals {
  folder_id = "b1g4n9nao0v3o7b2j7ds"
  sa_id = "aje8d1r5rvu1gio46bdc" # service accaunt id
  cloud_id = "b1ghhrj8r7kl2rudla5k"
  image_id = "fd8vmcue7aajpmeo39kk" #ubuntu2004_lts
  zone = "ru-central1-a"
  user_name = "sgoryunov"
  bucket_name = "bucket4atrifacts"
}
provider "yandex" {
  token     = var.token
  cloud_id  = local.cloud_id
  folder_id = local.folder_id
  zone      = local.zone
}

#  Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = local.sa_id
  description        = "static access key for object storage"
}
#Creare bucket for articacts storage
resource "yandex_storage_bucket" "artifacts" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket = local.bucket_name
}

# creates instances
resource "yandex_compute_instance" "build" {
  name        = "devops14-1"
  
  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
      size = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

  provisioner "file" {
    source      = "/home/${local.user_name}/.s3cfg"
    destination = "/home/${local.user_name}/.s3cfg"
    connection {
      type     = "ssh"
      user     = local.user_name
      private_key = "${file("~/.ssh/id_rsa")}"
      host     = self.network_interface.0.nat_ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install git maven s3cmd -y",
      "git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git",
      "cd boxfuse-sample-java-war-hello/ && mvn package",
      "s3cmd --storage-class COLD put /home/sgoryunov/boxfuse-sample-java-war-hello/target/hello-1.0.war s3://${local.bucket_name}/hello-1.0.war"
    ]
    connection {
      type     = "ssh"
      user     = local.user_name
      private_key = "${file("~/.ssh/id_rsa")}"
      host     = self.network_interface.0.nat_ip_address
    }
  }
}

resource "yandex_compute_instance" "prod" {
  name        = "devops14-2"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
      size = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat = true
  }

  metadata = {
    user-data = "${file("./meta.txt")}"
  }

  provisioner "file" {
    source      = "/home/${local.user_name}/.s3cfg"
    destination = "/home/${local.user_name}/.s3cfg"
    connection {
      type     = "ssh"
      user     = local.user_name
      private_key = "${file("~/.ssh/id_rsa")}"
      host     = self.network_interface.0.nat_ip_address
    }
  }

  provisioner "remote-exec" {
    #when = 
    inline = [
      "sudo apt update",
      "sudo apt install tomcat9 s3cmd -y",
      "s3cmd get s3://${local.bucket_name}/hello-1.0.war hello-1.0.war",
      "sudo cp hello-1.0.war /var/lib/tomcat9/webapps/"
    ]
    connection {
      type     = "ssh"
      user     = local.user_name
      private_key = "${file("~/.ssh/id_rsa")}"
      host     = self.network_interface.0.nat_ip_address
    }
  }
  depends_on = [
    yandex_compute_instance.build,
  ]
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}
resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

#get instance IP
output "public_ip_address_build" {
  value = yandex_compute_instance.build.network_interface.0.nat_ip_address
}
#get instance IP
output "public_ip_address_prod" {
  value = yandex_compute_instance.prod.network_interface.0.nat_ip_address
}