variable RG {
    description = "Resource Group name"
    default = "trng201808director-rg"
}
variable location {
    description = "Azure region"
    default = "East US"
}
    
variable VNET {
    default = "trng2018director-vnet"
}
variable NSG {
    default = "trng2018director-nsg"
}
variable "private_key_path" {
    description = "Path to the private ssh key"
    default = "~/.ssh/toby-azure"
}
variable "PROXY_USER" {
    description = "User to connect to proxy as"
    default = "pxuser"
}
variable "PROXY_USER_PASSWORD" {
    description = "Proxy user's password"
    default = "proxy"
}
variable "PROXY_PORT" {
    description = "Proxy Port"
    default = 3128
}
