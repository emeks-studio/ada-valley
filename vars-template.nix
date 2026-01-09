rec {
  vm = {
    sharedFolder = "/usr/share/ada-valley";
    vmMemory = "8192";
    tapInterface = "tap0";
  };
  cardanoNode = {
    # Variable indicating the file path to configuration files and scripts
    # related to operating your Cardano node
    nodeWorkingDirectoryName = "cardano-node";
    # Variable indicating the Cardano 
    # network cluster where your node runs. Available options:
    # "mainnet", "testnet-preprod", "testnet-preview"
    nodeConfig = "mainnet";
  };
}