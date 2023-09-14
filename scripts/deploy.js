// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { ethers } = require("hardhat");
const fs = require("fs")
async function main() {
  const owner = await ethers.getSigners();

  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy(owner[0].address,
  ethers.parseEther("10000000000"),
  "name",
  "name");
    
  await token.waitForDeployment();
  let softCap = ethers.parseEther("0.01");
  let hardCap = ethers.parseEther("0.04");
  let startTime = 0;
  let endTime = 1000000000000;
  let isPublic = true;
  let limitPerWallet = ethers.parseEther("0.04");
  let minimumPerWallet = ethers.parseEther("0.01");
  let tokenPrice = 1000;
  let tokenAddress = await token.getAddress();

//   const proxyAdmin = await hre.ethers.deployContract("DefaultProxyAdmin",[])
//   const presaleImp = await hre.ethers.deployContract("Presale",[])

//   console.log(`this is implementation contract address: ${await presaleImp.getAddress()}`);
// const impAddress = await presaleImp.getAddress()
//   const presaleABI = JSON.parse(
//     fs.readFileSync(
//       "./artifacts/contracts/presale-token.sol/Presale.json",
//       "utf-8"
//     )
//   ).abi

//   const iface = new ethers.Interface(presaleABI)
//   const callDataEncoded = iface.encodeFunctionData("initialize", [
//     softCap,
//     hardCap,
//     startTime,
//     endTime,
//     isPublic,
//     limitPerWallet,
//     minimumPerWallet,
//     tokenPrice,
//     tokenAddress,
    
//     "0xBBe737384C2A26B15E23a181BDfBd9Ec49E00248", //router
//     "0xaadb9ef09aaf53019ebe3ebb25aecbb2c9e63210", //pair
//     ethers.parseEther("100")
//   ])
//   console.log(callDataEncoded)
//   await token.connect(owner[0]).approve(impAddress, ethers.parseEther("10000"))
//   console.log(await token.connect(owner[0]).allowance(owner[0].address, impAddress));
//   console.log(owner[0].address);
//   const presale = await hre.ethers.deployContract("OptimizedTransparentUpgradeableProxy",
//     [impAddress, await proxyAdmin.getAddress(), callDataEncoded]
//   )
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
    
    "0xBBe737384C2A26B15E23a181BDfBd9Ec49E00248", //router
    "0xaadb9ef09aaf53019ebe3ebb25aecbb2c9e63210", //pair

   "0xd5C2A7BC67B80bd2A7A2DB3414B69c33CedE42a3"
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
