const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(
    "deploying contract using address",
    deployer.address,
    await deployer.getBalance().toString()
  );
  const Token = await ethers.getContractFactory("PancakeFlashLoan");
  const token = await Token.deploy();
  console.log("contract deployed at:", token.address);
}
main()
  .then(() => {
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
