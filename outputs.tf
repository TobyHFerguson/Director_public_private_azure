output "squid_public_ip" { value = "${azurerm_public_ip.squid_ip.ip_address}" }

output "squid_private_ip" { value = "${azurerm_network_interface.squid.private_ip_address}" }

output "public_proxy" { value = "http://${var.PROXY_USER}:${var.PROXY_USER_PASSWORD}@${azurerm_public_ip.squid_ip.ip_address}:${var.PROXY_PORT}" }

output "private_proxy" { 
    value = "http://${var.PROXY_USER}:${var.PROXY_USER_PASSWORD}@${azurerm_network_interface.squid.private_ip_address}:${var.PROXY_PORT}" 
}

output "director_url" { value = "http://${azurerm_network_interface.director.private_ip_address}:7189" }

output "private test machine private ip" { value = "${azurerm_network_interface.private-test.private_ip_address}" }
