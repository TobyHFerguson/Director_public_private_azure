provider "azurerm" {
}

resource "azurerm_resource_group" "RG" {
    name = "Training_2018_RG"
    location = "West US 2"
}

resource "azurerm_network_security_group" "NSG" {
    name                = "${var.NSG}"
    location            = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
}

resource "azurerm_network_security_rule" "ssh_inbound" {
  name                        = "Allow SSH inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.RG.name}"
  network_security_group_name = "${azurerm_network_security_group.NSG.name}"
}

resource "azurerm_network_security_rule" "proxy_inbound" {
  name                        = "Allow Proxy inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3128"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.RG.name}"
  network_security_group_name = "${azurerm_network_security_group.NSG.name}"
}

resource "azurerm_virtual_network" "VNET" {
    name                = "${var.VNET}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
    address_space       = ["10.16.0.0/16"]
    location            = "${azurerm_resource_group.RG.location}"

}

resource "azurerm_route_table" "private" {
  name                = "private_route_table"
  location            = "${azurerm_resource_group.RG.location}"
  resource_group_name = "${azurerm_resource_group.RG.name}"

  route {
    name           = "Internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "none"
  }
}

resource "azurerm_subnet" "public" {
    name = "public"
    resource_group_name  = "${azurerm_resource_group.RG.name}"
    virtual_network_name = "${azurerm_virtual_network.VNET.name}"
    address_prefix       = "10.16.0.0/24"
    network_security_group_id = "${azurerm_network_security_group.NSG.id}"
}


resource "azurerm_subnet" "private" {
    name = "private"
    resource_group_name  = "${azurerm_resource_group.RG.name}"
    virtual_network_name = "${azurerm_virtual_network.VNET.name}"
    address_prefix       = "10.16.1.0/24"
    network_security_group_id = "${azurerm_network_security_group.NSG.id}"
    route_table_id = "${azurerm_route_table.private.id}"
}

resource "azurerm_public_ip" "squid_ip" {
    name = "squid_ip"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "squid" {
    name = "squid-nic"
  location = "${azurerm_resource_group.RG.location}"
  resource_group_name = "${azurerm_resource_group.RG.name}"

  ip_configuration {
    name                          = "squid-ip"
    subnet_id                     = "${azurerm_subnet.public.id}"
      private_ip_address_allocation = "dynamic"
      public_ip_address_id = "${azurerm_public_ip.squid_ip.id}"
  }
}


// data "aws_vpc" "vpc" {
//     id = "${var.VPC_ID}"
// }

// data "aws_internet_gateway" "igw" {
//     filter {
// 	name = "attachment.vpc-id"
// 	values = ["${var.VPC_ID}"]
//     }
// }


// resource "aws_subnet" "public" {
//     vpc_id = "${var.VPC_ID}"
//     cidr_block = "${var.PUBLIC_SUBNET_CIDR}"
//     availability_zone = "${var.AWS_REGION}a"
//     tags { owner = "${var.OWNER}", Name = "public TFORM"}
// }

// resource "aws_route_table" "public" {
//     vpc_id = "${var.VPC_ID}"
//     tags { owner = "${var.OWNER}", Name = "public TFORM" }
// }

// resource "aws_route" "public" {
//     destination_cidr_block = "0.0.0.0/0"
//     gateway_id = "${data.aws_internet_gateway.igw.id}"
//     route_table_id = "${aws_route_table.public.id}"
// }

// resource "aws_route_table_association" "public" {
//     subnet_id      = "${aws_subnet.public.id}"
//     route_table_id = "${aws_route_table.public.id}"
// }

// resource "aws_security_group" "SG" {
//     name = "MACathon Security Group"
//     vpc_id = "${var.VPC_ID}"
// }

// resource "aws_security_group_rule" "PROXY_ACCESS" {
//     type = "ingress"
//     cidr_blocks=["0.0.0.0/0"]
//     description = "Allow inbound HTTP traffic to the proxy from anywhere"
//     protocol = "tcp"
//     from_port = "3128"
//     to_port = "3128"
//     security_group_id="${aws_security_group.SG.id}"
// }
// resource "aws_security_group_rule" "SSH" {
//     type = "ingress"
//     cidr_blocks=["0.0.0.0/0"]
//     description = "Allow inbound SSH access to the NAT instance from anywhere"
//     protocol = "tcp"
//     from_port = "22"
//     to_port = "22"
//     security_group_id="${aws_security_group.SG.id}"
// }
// resource "aws_security_group_rule" "OUTBOUND_OPEN" {
//     type = "egress"
//     cidr_blocks = ["0.0.0.0/0"]
//     description = "Allow outbound access to the internet"
//     protocol = "-1"
//     from_port = 0
//     to_port = 0
//     security_group_id="${aws_security_group.SG.id}"
// }

// resource "aws_subnet" "private" {
//     vpc_id = "${var.VPC_ID}"
//     cidr_block = "${var.PRIVATE_SUBNET_CIDR}"
//     availability_zone = "${var.AWS_REGION}a"
//     tags { owner = "${var.OWNER}", Name = "private TFORM"}
// }

// resource "aws_route_table" "private" {
//     vpc_id = "${var.VPC_ID}"
//     tags { owner = "${var.OWNER}", Name = "private TFORM" }
// }

// resource "aws_route_table_association" "private" {
//     subnet_id      = "${aws_subnet.private.id}"
//     route_table_id = "${aws_route_table.private.id}"
// }


// resource "aws_instance" "test" {
//     ami = "${var.CENTOS_AMI}"
//     instance_type = "t2.nano"
//     security_groups = ["${aws_security_group.SG.id}"]
//     subnet_id = "${aws_subnet.private.id}"
//     associate_public_ip_address = false
//     key_name = "${aws_key_pair.kp.key_name}"
//     tags = { Name = "Test instance", owner = "${var.OWNER}" }
// }

// resource "aws_instance" "squid" {
//     ami = "${var.CENTOS_AMI}"
//     instance_type = "t2.nano"
//     security_groups = ["${aws_security_group.SG.id}"]
//     subnet_id = "${aws_subnet.public.id}"
//     associate_public_ip_address = true
//     key_name = "${aws_key_pair.kp.key_name}"
//     tags = { Name = "squid instance", owner = "${var.OWNER}" }
//     connection {
// 	type     = "ssh"
// 	user     = "centos"
// 	private_key = "${file(var.private_key_path)}"
//     }

//     provisioner "file" {
// 	source = "${path.module}/provision_squid.sh"
// 	destination = "/tmp/provision_squid.sh"
//     }


//     provisioner "file" {
// 	source= "${path.module}/install_repos.sh"
// 	destination = "/tmp/install_repos.sh"
//     }

//     provisioner "remote-exec" {
// 	inline = [
// 	    "sudo chmod +x /tmp/*.sh",
// 	    "sudo /tmp/provision_squid.sh",
// 	    "sudo /tmp/install_repos.sh",
// 	    "sudo su -c 'echo ${data.aws_vpc.vpc.cidr_block} allow >>/etc/chrony.conf'"
// 	]
//     }
// }

// resource "aws_key_pair" "kp" {
//     key_name_prefix = "${var.key_name}"
//     public_key = "${file(var.public_key_path)}"
// }
