const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
const { impersonateFundErc20 } = require("./../utils/utilities");
const {
  abi,
} = require("./../artifacts/contracts/interfaces/IERC20.sol/IERC20.json");
const provider = ethers.getDefaultProvider([
  "https://data-seed-prebsc-1-s1.binance.org:8545/",
]);

describe("FlashLoan contract", () => {
  let FLASH_SWAP,
    BORROW_AMOUNT,
    FUND_AMOUNT,
    initialFUNDhuman,
    txArbitrage,
    gasUsedUSD;
  let DECIMALS = 18;
  const BUSD_WHALE = "0xf977814e90da44bfa03b6295a0616a897441acec";
  const WBNB = "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c";
  const BUSD = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  const CROX = "0x2c094f5a7d1146bb93850f629501eb749f6ed491";
  const CAKE = "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82";
  const BASE_TOKEN_ADDRESS = BUSD;
  const tokenBase = new ethers.Contract(BASE_TOKEN_ADDRESS, abi, provider);

  beforeEach(async () => {
    const [owner] = await ethers.getSigners();
    const whale_balance = await provider.getBalance(BUSD_WHALE);
    console.log(whale_balance);
    expect(whale_balance).not.equal("0");
    //deploy the smart contract
    const FlashSwap = await ethers.getContractFactory("PancakeFlashLoan");
    FLASH_SWAP = await FlashSwap.deploy();
    await FLASH_SWAP.deployed();

    //borrow
    const borrowHuman = "1";
    BORROW_AMOUNT = ethers.utils.parseUnits(borrowHuman, DECIMALS);
    //fund the contract
    initialFUNDhuman = "100";
    FUND_AMOUNT = ethers.utils.parseUnits(initialFUNDhuman, DECIMALS);
    await impersonateFundErc20(
      tokenBase,
      BUSD_WHALE,
      FLASH_SWAP.address,
      initialFUNDhuman
    );
    describe("arbitrage execution", () => {
      it("checks contract is funded", async () => {
        const flashLoanBalance = await FLASH_SWAP.getBalanceOfToken(
          BASE_TOKEN_ADDRESS
        );
        const flashLoanBalanceHuman = ethers.utils.formatUnits(
          flashLoanBalance,
          DECIMALS
        );
        expect(Number(flashLoanBalanceHuman)).equal(Number(initialFUNDhuman));
      });
      it("should complete the arbitrage", async () => {
        txArbitrage = await FLASH_SWAP.startArbitrage(
          BASE_TOKEN_ADDRESS,
          BORROW_AMOUNT
        );
        assert(txArbitrage);
        //checking balances
        const contractBUSDBalance = await FLASH_SWAP.getBalanceOfToken(BUSD);
        const formattedBUSDBalance = Number(
          ethers.utils.formatUnits(contractBUSDBalance, DECIMALS)
        );
        console.log(formattedBUSDBalance);
        const contractCROXBalance = await FLASH_SWAP.getBalanceOfToken(CROX);
        const formattedCROXBalance = Number(
          ethers.utils.formatUnits(contractCROXBalance, DECIMALS)
        );
        console.log(formattedCROXBalance);
        const contractCAKEBalance = await FLASH_SWAP.getBalanceOfToken(CAKE);
        const formattedCAKEBalance = Number(
          ethers.utils.formatUnits(contractCAKEBalance, DECIMALS)
        );
        console.log(formattedCAKEBalance);
      });
    });
  });
});
