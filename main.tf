provider "azurerm" {
}

resource "azurerm_resource_group" "RG" {
    name = "${var.RG}"
    location = "${var.location}"
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

resource "azurerm_virtual_machine" "squid" {
    name = "squid"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
    network_interface_ids = ["${azurerm_network_interface.squid.id}"]

    os_profile_linux_config {
	disable_password_authentication = true
	ssh_keys = {
	    key_data = "${file("~/.ssh/toby-azure.pub")}"
	    path = "/home/centos/.ssh/authorized_keys"
	}
    }
    vm_size = "Standard_DS14-8_v2"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true
    os_profile {
	computer_name = "squid"
	admin_username = "centos"
    }
    // Get this using az vm image list --all --publisher Cloudera --offer cloudera-centos-os --sku 7_4
    storage_image_reference {
	offer = "cloudera-centos-os",
	publisher = "cloudera",
	sku = "7_4",
	version = "2.0.7"
    }
    storage_os_disk {
	name = "root_disk"
	create_option = "FromImage"
	disk_size_gb = 100
    }
    // Get this using az vm image show --urn cloudera:cloudera-centos-os:7_4:2.0.7
    plan {
	name = "7_4",
	product = "cloudera-centos-os",
	publisher = "cloudera"
    }

    connection {
	type     = "ssh"
	user     = "centos"
	private_key = "${file(var.private_key_path)}"
    }

    // copy the directory squid_scripts to /tmp/squid_scripts on the target machine
    provisioner "file" {
	source = "${path.module}/squid_scripts"
	destination = "/tmp"
    }

    provisioner "remote-exec" {
	inline = [
	    "sudo chmod +x /tmp/squid_scripts/*.sh",
	    "sudo /tmp/squid_scripts/provision_squid.sh ${var.PROXY_USER} ${var.PROXY_USER_PASSWORD} ${var.PROXY_PORT}",
	    "sudo /tmp/squid_scripts/install_repos.sh",
	    "sudo su -c 'echo allow ${azurerm_virtual_network.VNET.address_space[0]} >>/etc/chrony.conf'",
	    "sudo systemctl restart chronyd"
	]
    }
}

resource "azurerm_public_ip" "director_ip" {
    name = "director_ip"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_network_interface" "director" {
    name = "director-nic"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"

    ip_configuration {
	name                          = "director-ip"
	subnet_id                     = "${azurerm_subnet.public.id}"
	private_ip_address_allocation = "dynamic"
	public_ip_address_id = "${azurerm_public_ip.director_ip.id}"
    }
}

resource "azurerm_virtual_machine" "director" {
    name = "director"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
    network_interface_ids = ["${azurerm_network_interface.director.id}"]

    os_profile_linux_config {
	disable_password_authentication = true
	ssh_keys = {
	    key_data = "${file("~/.ssh/toby-azure.pub")}"
	    path = "/home/centos/.ssh/authorized_keys"
	}
    }
    vm_size = "Standard_DS14-8_v2"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true
    os_profile {
	computer_name = "director"
	admin_username = "centos"
    }
    // Get this using az vm image list --all --publisher Cloudera --offer cloudera-centos-os --sku 7_4
    storage_image_reference {
	offer = "cloudera-centos-os",
	publisher = "cloudera",
	sku = "7_4",
	version = "2.0.7"
    }
    storage_os_disk {
	name = "director_root_disk"
	create_option = "FromImage"
	disk_size_gb = 100
    }
    // Get this using az vm image show --urn cloudera:cloudera-centos-os:7_4:2.0.7
    plan {
	name = "7_4",
	product = "cloudera-centos-os",
	publisher = "cloudera"
    }

    connection {
	type     = "ssh"
	user     = "centos"
	private_key = "${file(var.private_key_path)}"
    }

    provisioner "file" {
	source = "${path.module}/director_scripts"
	destination = "/tmp"
    }

    provisioner "remote-exec" {
	inline = [
	    "sudo chmod +x /tmp/director_scripts/*.sh",
	    "sudo /tmp/director_scripts/install_director.sh http://${var.PROXY_USER}:${var.PROXY_USER_PASSWORD}@${azurerm_network_interface.squid.private_ip_address}:${var.PROXY_PORT}",
	    "sudo systemctl restart cloudera-director-server"
	]
    }    
}

resource "azurerm_network_interface" "private-test" {
    name = "private-test-nic"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"

    ip_configuration {
	name                          = "private-test-ip"
	subnet_id                     = "${azurerm_subnet.private.id}"
	private_ip_address_allocation = "dynamic"
    }
}

resource "azurerm_virtual_machine" "private-test" {
    name = "private-test"
    location = "${azurerm_resource_group.RG.location}"
    resource_group_name = "${azurerm_resource_group.RG.name}"
    network_interface_ids = ["${azurerm_network_interface.private-test.id}"]

    os_profile_linux_config {
	disable_password_authentication = true
	ssh_keys = {
	    key_data = "${file("~/.ssh/toby-azure.pub")}"
	    path = "/home/centos/.ssh/authorized_keys"
	}
    }
    vm_size = "Standard_DS14-8_v2"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true
    os_profile {
	computer_name = "private-test"
	admin_username = "centos"
    }
    // Get this using az vm image list --all --publisher Cloudera --offer cloudera-centos-os --sku 7_4
    storage_image_reference {
	offer = "cloudera-centos-os",
	publisher = "cloudera",
	sku = "7_4",
	version = "2.0.7"
    }
    storage_os_disk {
	name = "private_test_root_disk"
	create_option = "FromImage"
	disk_size_gb = 100
    }
    // Get this using az vm image show --urn cloudera:cloudera-centos-os:7_4:2.0.7
    plan {
	name = "7_4",
	product = "cloudera-centos-os",
	publisher = "cloudera"
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
