import { BigNumber } from "ethers";
import { starknet, ethers } from "hardhat";
import { expect } from "chai";
import { StarknetContract, StarknetContractFactory, Account } from "hardhat/types/runtime";

import { shortString, uint256, number } from "starknet";
import BN from "bn.js";

const init_balance = "1000000000000000000";

describe("Deploy ERC20 contract", async function () {
  this.timeout(6_000_000);

  let testERC20ContractFactory: StarknetContractFactory;
  let tokenContract: StarknetContract;
  let account0: Account;
  let account1: Account;

  before(async () => {
    // Use preconfigured accounts
    const response = await starknet.devnet.getPredeployedAccounts();
    account0 = await starknet.OpenZeppelinAccount.getAccountFromAddress(response[0].address, response[0].private_key);
    account1 = await starknet.OpenZeppelinAccount.getAccountFromAddress(response[1].address, response[1].private_key);

    testERC20ContractFactory = await starknet.getContractFactory("ERC20_mintable");
    const classHash = await account0.declare(testERC20ContractFactory, {
      maxFee: 200000000000000n,
    });

    tokenContract = await account0.deploy(testERC20ContractFactory, {
      name: shortString.encodeShortString("TEST"),
      symbol: shortString.encodeShortString("TST"),
      decimals: 18,
      initial_supply: { low: init_balance, high: 0 },
      recipient: account0.address,
      bridge: BigNumber.from("0xd6dAAC426085Ab6Af426ecaC14C2bC92FfE36Fa5"),
    });
  });

  describe("Test contract deployment", async () => {
    it("Get contract symbol", async () => {
      let res = await tokenContract.call("symbol");
      expect(shortString.decodeShortString(BigNumber.from(res.symbol).toHexString())).to.eq("TST");
    });

    it("Checks the supply of the account0", async () => {
      let res = await tokenContract.call("balanceOf", { account: account0.address });
      expect(uint256.uint256ToBN(res.balance)).to.eq(init_balance);
    });

    it("Transfer funds to account 1", async () => {
      let res = await tokenContract.call("balanceOf", { account: account0.address });
      expect(uint256.uint256ToBN(res.balance)).to.eq(init_balance);

      let transferNumber = "1000";
      let transferAmount = uint256.bnToUint256(transferNumber);

      let transferArgs = { recipient: account1.address, amount: transferAmount };

      const fee = await account0.estimateFee(tokenContract, "transfer", {
        recipient: account1.address,
        amount: transferAmount,
      });

      await account0.invoke(tokenContract, "transfer", transferArgs, { maxFee: fee.amount * 2n });

      res = await tokenContract.call("balanceOf", { account: account0.address });
      expect(uint256.uint256ToBN(res.balance)).to.eq(BigNumber.from(init_balance).sub(transferNumber));
    });
  });
});
