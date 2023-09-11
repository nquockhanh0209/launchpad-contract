// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  const owner = await ethers.getSigners();
  console.log(owner);
  const token = await hre.ethers.deployContract("Token", [
    "0xd5C2A7BC67B80bd2A7A2DB3414B69c33CedE42a3",
    ethers.parseEther("10000000000"),
  ]);
  console.log(token);
  let softCap = 20;
  let hardCap = 50;
  let startTime = 0;
  let endTime = 1000000000000;
  let isPublic = true;
  let limitPerWallet = 1000;
  let minimumPerWallet = 100;
  let tokenPrice = ethers.parseEther("0.01");
  let tokenAddress = await token.getAddress();

  const presale = await hre.ethers.deployContract("Presale", [
    softCap,
    hardCap,
    startTime,
    endTime,
    isPublic,
    limitPerWallet,
    minimumPerWallet,
    tokenPrice,
    tokenAddress,
  ]);

  await presale.waitForDeployment();

  console.log(
    `contract presale is deploy at ${await presale.getAddress()} with token address is ${await token.getAddress()}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
