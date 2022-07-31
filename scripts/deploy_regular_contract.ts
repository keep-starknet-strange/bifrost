import { ethers, utils, Contract, providers, Wallet, constants } from "ethers";

import * as dotenv from "dotenv";

import fs from "fs";
import path from "path";

dotenv.config();

const GWEI = 1000000000;

const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL || "http://127.0.0.1:8545";
const MNEMONIC = process.env.MNEMONIC || "";

if (MNEMONIC === "") {
  console.warn("Must provide MNEMONIC environment variable");
  process.exit(1);
}

const provider = new providers.StaticJsonRpcProvider(ETHEREUM_RPC_URL);

const deployerWallet = Wallet.fromMnemonic(MNEMONIC).connect(provider);

async function main() {
  console.log("Owner Wallet Address: " + (await deployerWallet.getAddress()));

  var jsonFile = path.resolve(__dirname, "../artifacts/contracts/StarkNetERC20Bridge.sol/StarkNetERC20Bridge.json");
  var parsed = JSON.parse(fs.readFileSync(jsonFile).toString());

  let bytecode = parsed.bytecode;

  let nonce = await provider.getTransactionCount(deployerWallet.address);
  console.log("Nonce", nonce);

  const factory = new ethers.ContractFactory(parsed.abi, parsed.bytecode, deployerWallet);
  const contract = await factory.deploy({
    maxFeePerGas: utils.parseUnits("20", 9),
    maxPriorityFeePerGas: utils.parseUnits("1.5", 9),
    gasLimit: 4000000,
    nonce,
  });
  await contract.deployed();
  console.log(`Deployment successful! Contract Address: ${contract.address}`);
}

main();
