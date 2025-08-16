import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

const deployPriceConsumerV3: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // ETH/USD price feed address on Base Sepolia
  const priceFeedAddress = "0x4aDC67696bA383F43DD60A9e78F2C97C18c13F42";

  await deploy("PriceConsumerV3", {
    from: deployer,
    // Contract constructor arguments
    args: [priceFeedAddress],
    log: true,
    autoMine: true,
  });

  // Get the deployed contract to interact with it after deploying.
  const priceConsumerV3 = await hre.ethers.getContract<Contract>("PriceConsumerV3", deployer);
  console.log("📊 Latest ETH/USD Price:", (await priceConsumerV3.getLatestPrice()).toString());
};

export default deployPriceConsumerV3;

deployPriceConsumerV3.tags = ["PriceConsumerV3"];
