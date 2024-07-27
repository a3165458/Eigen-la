#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 节点安装功能
function install_eigenlayer() {
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential docker.io 

# 安装 Docker compose 最新版本
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
    docker compose version

# 安装 Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

# 克隆仓库
    git clone https://github.com/Layr-Labs/eigenlayer-cli.git
    cd eigenlayer-cli
    mkdir -p build
    go build -o build/eigenlayer cmd/eigenlayer/main.go
    cp ./build/eigenlayer /usr/local/bin/

# 创建ECDSA 和操作员
    read -p "请输入你想设置的ECDSA 账户名称:" your_ecdsa_name

    read -p "请输入你想设置的BLS 账户名称:" your_bls_name
    
    eigenlayer operator keys create --key-type ecdsa $your_ecdsa_name | cat
    eigenlayer operator keys create --key-type bls $your_bls_name | cat

    echo "=============================备份好钱包和助记词，下方需要使用==================================="
    echo "=============================Make sure to backup your wallet and mnemonic phrase, it will be needed below==================================="

    # 确认备份
    read -p "是否已经备份好助记词? " backup_confirmed
    if [ "$backup_confirmed" != "y" ]; then
            echo "请先备份好助记词,然后再继续执行脚本。"
            exit 1
    fi
    
# 设置操作员文件
cd pkg/operator/config

read -p "请输入你的ECDSA账户的钱包地址: " ecdsa_address

read -p "请输入你的METADATA.JSON的RAW链接: " metajson_url

read -p "请输入你的ECDSA账户名称: " ecdsa_name

cat > /root/eigenlayer-cli/pkg/operator/config/operator.yaml << EOF
# All the below fields are required for successful operator registration.

# To learn more about operator fields
# https://github.com/Layr-Labs/eigenlayer-contracts/blob/92ccacc868785350973afc15e90a18dcd39fbc0b/src/contracts/interfaces/IDelegationManager.sol#L21:
operator:
  # This is the standard Ethereum address format (ex: 0x6a8c0D554a694899041E52a91B4EC3Ff23d8aBD5) of your operator
  # which is the ecdsa key you created or imported using EigenLayer CLI
  address: ${ecdsa_address}
  # This is the standard Ethereum address format (ex: 0x6a8c0D554a694899041E52a91B4EC3Ff23d8aBD5)
  # This is the address where your operator will receive earnings. This could be same as operator address
  earnings_receiver_address: ${ecdsa_address}
  # This is the standard Ethereum address format (0x...)
  # This is the address which operator will use to approve delegation requests from stakers.
  # if set, this address must sign and approve new delegation from Stakers to this Operator
  # For now, you can leave it  with the default value for un-gated delegation requests
  # Once we enable gated delegation requests, you can update this field with the address of the approver
  delegation_approver_address: 0x0000000000000000000000000000000000000000
  # Please refer to this link for more details on this field https://github.com/Layr-Labs/eigenlayer-contracts/blob/92ccacc868785350973afc15e90a18dcd39fbc0b/src/contracts/interfaces/IDelegationManager.sol#L33:
  # Please keep this field to 0, and it can be updated later using EigenLayer CLI
  staker_opt_out_window_blocks: 0
  metadata_url: ${metajson_url}

# EigenLayer Delegation manager contract address
# This will be provided by EigenLayer team
el_delegation_manager_address: 0xA44151489861Fe9e3055d95adC98FbD462B948e7

# ETH RPC URL to the ethereum node you are using for on-chain operations
eth_rpc_url: https://holesky.drpc.org

# Signer Type to use
# Supported values: local_keystore, fireblocks, web3
signer_type: local_keystore

# Full path to local ecdsa private key store file
private_key_store_path: /root/.eigenlayer/operator_keys/${ecdsa_name}.ecdsa.key.json

# Chain ID: 1 for mainnet, 17000 for holesky, 31337 for local
chain_id: 17000

# If you are using Fireblocks as your signer, please provide the following details
fireblocks:
    # Fireblocks API Key
    api_key:

    # Fireblocks Secret Key storage type: plain_text, aws_secret_manager
    secret_storage_type:

    # Fireblocks Secret Key
    # If secret_storage_type is plain_text, this should be the secret key
    # If secret_storage_type is aws_secret_manager, this should be the secret key name in AWS Secret Manager
    secret_key:

    # Fireblocks Base URL
    base_url: https://api.fireblocks.io/

    # Fireblocks Vault Account Name
    vault_account_name:

    # Fireblocks AWS Region (if secret_storage_type is aws_secret_manager)
    aws_region:

    # Fireblocks API Timeout
    timeout: 3

# If you are using web3 as your signer, please provide the following details
# https://docs.web3signer.consensys.io/
web3:
  # Web3 Signer URL
  url:
  
EOF

# 注册验证者
eigenlayer operator register operator.yaml

eigenlayer operator status operator.yaml

echo "EigenLayer 部署完成"

}

# 安装EigenDA
function install_EigenDA() {

git clone https://github.com/Layr-Labs/eigenda-operator-setup.git
cd eigenda-operator-setup/holesky

read -p "请输入你的ECDSA账户的钱包私钥: " ecdsa_priv
read -p "请输入你的bls账户的钱包私钥: " bls_priv
read -p "请输入你的设备ip: " local_ip
read -p "请输入你设置的ECDSA 账户名称:" your_ecdsa_name
read -p "请输入你设置的BLS 账户名称:" your_bls_name
read -p "请输入你设置的ECDSA 账户名称:" ecdsa_passwd
read -p "请输入你设置的BLS 账户名称:" bls_passwd   


cat >> .env << EOF
MAIN_SERVICE_IMAGE=ghcr.io/layr-labs/eigenda/opr-node:0.7.0-rc.1
NETWORK_NAME=eigenda-network
MAIN_SERVICE_NAME=eigenda-native-node

# These are used for testing purpose
NODE_TEST_PRIVATE_BLS=$bls_priv
NODE_PRIVATE_KEY=$ecdsa_priv

# EigenDA specific configs
NODE_EXPIRATION_POLL_INTERVAL=180
NODE_CACHE_ENCODED_BLOBS=true
NODE_NUM_WORKERS=1
NODE_DISPERSAL_PORT=32005

# This is a dummy value for now. This won't be used as we are explicitly asking for quorum while opting in/out
# In future release, this will be removed
NODE_QUORUM_ID_LIST=0

NODE_VERBOSE=true
NODE_RETRIEVAL_PORT=32004
NODE_TIMEOUT=20s
NODE_SRS_ORDER=268435456
NODE_SRS_LOAD=131072

# If you are using a reverse proxy in a shared network space, the reverse proxy should listen at $NODE_DISPERSAL_PORT
# and forward the traffic to $NODE_INTERNAL_DISPERSAL_PORT, and similarly for retrieval. The DA node will register the 
# $NODE_DISPERSAL_PORT port on the chain and listen for the reverse proxy at $NODE_INTERNAL_DISPERSAL_PORT.
NODE_INTERNAL_DISPERSAL_PORT=${NODE_DISPERSAL_PORT}
NODE_INTERNAL_RETRIEVAL_PORT=${NODE_RETRIEVAL_PORT} 

# EigenDA mounted locations
NODE_ECDSA_KEY_FILE=/app/operator_keys/ecdsa_key.json
NODE_BLS_KEY_FILE=/app/operator_keys/bls_key.json
NODE_G1_PATH=/app/g1.point
NODE_G2_POWER_OF_2_PATH=/app/g2.point.powerOf2
NODE_CACHE_PATH=/app/cache
NODE_LOG_PATH=/app/logs/opr.log
NODE_DB_PATH=/data/operator/db

# Node logs configs
NODE_LOG_LEVEL=debug
NODE_LOG_FORMAT=text

# Metrics specific configs
NODE_ENABLE_METRICS=true
NODE_METRICS_PORT=9092

# Node API specific configs
NODE_ENABLE_NODE_API=true
NODE_API_PORT=9091

# holesky smart contracts
NODE_EIGENDA_SERVICE_MANAGER=0xD4A7E1Bd8015057293f0D0A557088c286942e84b
NODE_BLS_OPERATOR_STATE_RETRIVER=0xB4baAfee917fb4449f5ec64804217bccE9f46C67

# Churner URL
NODE_CHURNER_URL=churner-holesky.eigenda.xyz:443

# The name of the header used to get the client IP address
# If set to empty string, the IP address will be taken from the connection.
# The rightmost value of the header will be used.
NODE_CLIENT_IP_HEADER=x-real-ip
# How often to check the public IP address of the node. Set this to 0 to disable
# automatic IP address updating (if you have a stable IP address)
NODE_PUBLIC_IP_CHECK_INTERVAL=10s

###############################################################################
####### TODO: Operators please update below values for your node ##############
###############################################################################
# TODO: IP of your node
NODE_HOSTNAME=$local_ip

# TODO: Node Nginx config
NODE_NGINX_CONF_HOST=../resources/rate-limit-nginx.conf

# TODO: Operators need to point this to a working chain rpc
NODE_CHAIN_RPC=http://95.217.74.216:8545
NODE_CHAIN_ID=17000

# TODO: Operators need to update this to their own paths
USER_HOME=/root/
EIGENLAYER_HOME=/root/.eigenlayer
EIGENDA_HOME=/root/.eigenlayer/eigenda/

NODE_LOG_PATH_HOST=${EIGENDA_HOME}/logs
NODE_G1_PATH_HOST=${USER_HOME}/eigenda-operator-setup/resources/g1.point
NODE_G2_PATH_HOST=${USER_HOME}/eigenda-operator-setup/resources/g2.point.powerOf2
NODE_DB_PATH_HOST=${EIGENDA_HOME}/db
NODE_CACHE_PATH_HOST=${USER_HOME}/eigenda-operator-setup/resources/cache

# TODO: Operators need to update this to their own keys
NODE_ECDSA_KEY_FILE_HOST=${EIGENLAYER_HOME}/operator_keys/$your_ecdsa_name.key.json
NODE_BLS_KEY_FILE_HOST=${EIGENLAYER_HOME}/operator_keys/$your_bls_name.bls.key.json

# TODO: The ip provider service used to obtain a node's public IP [seeip (default), ipify)
NODE_PUBLIC_IP_PROVIDER=seeip

# TODO: Operators need to add password to decrypt the above keys
# If you have some special characters in password, make sure to use single quotes
NODE_ECDSA_KEY_PASSWORD='$ecdsa_passwd'
NODE_BLS_KEY_PASSWORD='$bls_passwd'

EOF

#加载文件
source .env
ls $USER_HOME $EIGENLAYER_HOME $EIGENDA_HOME

./run.sh opt-in 0

docker compose up -d

echo "EigenDA部署完成"

}

# 主菜单
function main_menu() {
    clear
    echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "Discord 群组:https://discord.gg/gk6Y7YqunR"
    echo "请选择要执行的操作:"
    echo "1. 安装Eigenlayer operator"
    echo "2. 安装Eigenlayer DA"
    read -p "请输入选项（1-2）: " OPTION

    case $OPTION in
    1) install_eigenlayer ;;
    2) check_service_status ;;

    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
