#!/bin/sh

TARGET_RESOURCE_GROUP=user0099-webapp-tmpl-rg
NUMBER_OF_WEB_SERVERS=3
WEBSV_IMAGE="/subscriptions/450f731f-ced6-417a-bfa1-3e69686598dc/resourceGroups/user0099-webapp-images-rg/providers/Microsoft.Compute/images/webapp-websv-image"
SSH_USER=webapusr
SSH_PKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCuL/P/IXcZAK4PwMMU/5CRcUzrPbJpIw0CvarOHxnUxwlQn0xlFMHwH8Q8Lizo9J+OAJ1o3j9xTkce/ORYxsVhvTvdUm0Gux9U6kAC2MT90P2V8dSJ/KTSRs/B/s1WVe0QVbCFZxkPX21DREVBYzLne31nUpd1moGf7ZpuJMWMZG7GPWquHxlwnSJqeJaELiSsd1KsFb31h+hmd+xbDlk0s1l0MfxMZMgvYhpR+Ehc9wssbp7JD8PlH1TBsMJ9yi7FovyN7SIdbSiRBWyyfrwwKYQBoNJfDPcHhzCGC+gifT/zswX4QnRf0u7hecUOWSId7vuQUT/HQzBzqhQU7MZ/ devops"

az configure --defaults group=${TARGET_RESOURCE_GROUP}
az network nsg create -n webapp-websv-nsg
az network nsg rule create \
    --nsg-name webapp-websv-nsg -n webapp-websv-nsg-http \
    --priority 1001 --protocol Tcp --destination-port-range 80
az network public-ip create -n webapp-pip
az network vnet create \
    -n webapp-vnet --address-prefixes 192.168.1.0/24 \
    --subnet-name webapp-vnet-sub --subnet-prefix 192.168.1.0/24
az network lb create \
    -n webapp-websv-lb --public-ip-address webapp-pip \
    --frontend-ip-name webapp-websv-lb-front \
    --backend-pool-name webapp-websv-lb-backpool
az network lb probe create \
    --lb-name webapp-websv-lb -n webapp-websv-lb-probe \
    --port 80 --protocol Http --path '/?lbprobe=1'
az network lb rule create \
    --lb-name webapp-websv-lb -n webapp-websv-lb-rule \
    --frontend-ip-name webapp-websv-lb-front --frontend-port 80 \
    --backend-pool-name webapp-websv-lb-backpool --backend-port 80 \
    --protocol tcp --probe-name webapp-websv-lb-probe
az vm availability-set create -n webapp-websv-as \
    --platform-update-domain-count 5 \
    --platform-fault-domain-count 2
for i in $(seq 1 ${NUMBER_OF_WEB_SERVERS}); do
(
az network nic create \
    -n webapp-websv${i}-nic \
    --private-ip-address 192.168.1.$((10 + ${i})) \
    --vnet-name webapp-vnet --subnet webapp-vnet-sub \
    --network-security-group webapp-websv-nsg \
    --lb-name webapp-websv-lb \
    --lb-address-pools webapp-websv-lb-backpool
az vm create \
    -n websv${i} --nics webapp-websv${i}-nic \
    --availability-set webapp-websv-as \
    --size Standard_F1 --storage-sku Standard_LRS \
    --image ${WEBSV_IMAGE} \
    --admin-username "${SSH_USER}" --ssh-key-value "${SSH_PKEY}"
)&
done
wait
echo http://$(az network public-ip show -n webapp-pip -o tsv --query ipAddress)/

