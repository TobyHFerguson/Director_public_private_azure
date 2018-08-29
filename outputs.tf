output "proxy public ip" { value = "${azurerm_public_ip.squid_ip.ip_address}" }

output "proxy private ip" { value = "${azurerm_network_interface.squid.private_ip_address}" }

output "http_proxy for external use" { value = "http://${var.PROXY_USER}:${var.PROXY_USER_PASSWORD}@${azurerm_public_ip.squid_ip.ip_address}:${var.PROXY_PORT}" }

output "http_proxy for internal use" {
    value = "http://${var.PROXY_USER}:${var.PROXY_USER_PASSWORD}@${azurerm_network_interface.squid.private_ip_address}:${var.PROXY_PORT}" 
}

output "director url" { value = "http://${azurerm_network_interface.director.private_ip_address}:7189" }

output "private test machine private ip" { value = "${azurerm_network_interface.private-test.private_ip_address}" }

output "proxy user name" { value = "${var.PROXY_USER}" }

output "proxy password" { value = "${var.PROXY_USER_PASSWORD}"}
