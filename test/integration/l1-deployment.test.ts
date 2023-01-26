import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract, ContractFactory } from "ethers";
import { starknet, network, ethers } from "hardhat";
import { Account, StarknetContractFactory, StarknetContract, HttpNetworkConfig } from "hardhat/types";
import { TIMEOUT } from "./constants";
import { expectAddressEquality } from "./util";
import { shortString, uint256 } from "starknet";

const TOKEN_NAME = "TEST";
const TOKEN_SYMBOL = "TST";

/**
 * Follows the example at https://www.cairo-lang.org/docs/hello_starknet/l1l2.html
 * Shows the communication between an L2 contract defined in l1l2.cairo
 * and an L1 contract defined in https://www.cairo-lang.org/docs/_static/L1L2Example.sol
 */
describe("L2->L1 bridging", function () {
  this.timeout(TIMEOUT);

  /**
   * The URL of the L1 network to interact with. It is expected to be already running.
   * Possibilities include and are not limited to:
   * - Hardhat node: https://hardhat.org/hardhat-network/#running-stand-alone-in-order-to-support-wallets-and-other-software
   * - Ganache node
   * - Goerli testnet
   * Supply the L1 network with `npx hardhat test --network <L1_NETWORK_NAME>`.
   * The network is expected to be defined in hardhat.config.
   * The `localhost` network is predefined, so `--network localhost` works for e.g. `npx hardhat node`.
   *
   * Make sure to run devnet as a separate instance, not integrated devnet
   * Run `npx hardhat node` for the L1 instance in a seprate terminal
   */
  const networkUrl: string = (network.config as HttpNetworkConfig).url;
  let L2contractFactory: StarknetContractFactory;
  let ERC20ContractFactory: StarknetContractFactory;
  let l2contract: StarknetContract;
  let tokenContract: StarknetContract;
  let L1L2Example: ContractFactory;
  let MockStarknetMessaging: ContractFactory;
  let StarknetBridge: ContractFactory;
  let starknetBridge: Contract;
  let mockStarknetMessaging: Contract;
  let l1l2Example: Contract;
  let signer: SignerWithAddress;
  let account: Account;
  let l2recipient: Account;

  before(async function () {
    const response = await starknet.devnet.getPredeployedAccounts();
    account = await starknet.OpenZeppelinAccount.getAccountFromAddress(response[0].address, response[0].private_key);
    l2recipient = await starknet.OpenZeppelinAccount.getAccountFromAddress(
      response[1].address,
      response[1].private_key,
    );

    // L2contractFactory = await starknet.getContractFactory("l1l2");
    // await account.declare(L2contractFactory);
    // l2contract = await account.deploy(L2contractFactory);

    // Deploy messaging contract
    const signers = await ethers.getSigners();
    signer = signers[0];

    MockStarknetMessaging = await ethers.getContractFactory("MockStarknetMessaging", signer);
    mockStarknetMessaging = await MockStarknetMessaging.deploy();
    await mockStarknetMessaging.deployed();

    // Deploy L2 ERC20 token
    ERC20ContractFactory = await starknet.getContractFactory("ERC20_mintable");
    const classHash = await account.declare(ERC20ContractFactory, {
      maxFee: 200000000000000n,
    });

    // Deploy L1 bridge
    const bridgeUtilsFactory = await ethers.getContractFactory("BridgeUtils");
    const bridgeUtils = await bridgeUtilsFactory.deploy();

    StarknetBridge = await ethers.getContractFactory("StarkNetERC20Bridge", {
      libraries: {
        "contracts/l1-contracts/BridgeUtils.sol:BridgeUtils": bridgeUtils.address,
      },
    });
    starknetBridge = await StarknetBridge.deploy(mockStarknetMessaging.address);

    const init_balance = "100000000000000000000";
    tokenContract = await account.deploy(ERC20ContractFactory, {
      name: shortString.encodeShortString(TOKEN_NAME),
      symbol: shortString.encodeShortString(TOKEN_SYMBOL),
      decimals: 18,
      initial_supply: { low: init_balance, high: 0 },
      recipient: account.address,
      bridge: BigNumber.from(starknetBridge.address),
    });
  });

  it("should deploy the messaging contract", async () => {
    const { address: deployedTo, l1_provider: L1Provider } = await starknet.devnet.loadL1MessagingContract(networkUrl);

    expect(deployedTo).not.to.be.undefined;
    expect(L1Provider).to.equal(networkUrl);
  });

  it("should load the already deployed contract if the address is provided", async () => {
    const { address: loadedFrom } = await starknet.devnet.loadL1MessagingContract(
      networkUrl,
      mockStarknetMessaging.address,
    );

    expect(mockStarknetMessaging.address).to.equal(loadedFrom);
  });

  it("Should deploy new l1 contract intance", async () => {
    /**
     * Load the mock messaging contract
     */

    await starknet.devnet.loadL1MessagingContract(networkUrl, mockStarknetMessaging.address);

    /**
     * Create l1 instance of the l2 token
     */

    await account.invoke(tokenContract, "create_l1_instance", {});

    /**
     * Flushing the L2 messages so that they can be consumed by the L1.
     */

    let flushL2Response = await starknet.devnet.flush();
    expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
    let flushL2Messages = flushL2Response.consumed_messages.from_l2;

    expect(flushL2Messages).to.have.a.lengthOf(1);
    expectAddressEquality(flushL2Messages[0].from_address, tokenContract.address);
    expectAddressEquality(flushL2Messages[0].to_address, starknetBridge.address);

    /**
     * Consume the L1 message by creating a new instance
     */

    let tx = await starknetBridge.createL1Instance(tokenContract.address, TOKEN_NAME, TOKEN_SYMBOL);
    let rec = await tx.wait();

    let l1ERC20contractAddress = await starknetBridge.l1Addresses(tokenContract.address);
    expect(l1ERC20contractAddress).to.not.eq(ethers.constants.AddressZero);

    // Just some address to send funds to
    const signers = await ethers.getSigners();
    let l1Recipient = signers[1];

    let BridgedERC20 = (MockStarknetMessaging = await ethers.getContractFactory("BridgedERC20"));
    let bridgedERC20 = BridgedERC20.attach(l1ERC20contractAddress).connect(l1Recipient);

    let balanceOfRandom = await bridgedERC20.balanceOf(l1Recipient.address);

    expect(balanceOfRandom).to.be.eq(0);

    let amount = "1000000000000000000";
    let transferAmount = uint256.bnToUint256(amount);

    await account.invoke(tokenContract, "bridge_tokens_to_l1", {
      l1_recipient: l1Recipient.address,
      amount: transferAmount,
    });

    /**
     * Flushing the L2 messages so that they can be consumed by the L1.
     */

    flushL2Response = await starknet.devnet.flush();
    expect(flushL2Response.consumed_messages.from_l1).to.be.empty;
    flushL2Messages = flushL2Response.consumed_messages.from_l2;

    expect(flushL2Messages).to.have.a.lengthOf(1);
    expectAddressEquality(flushL2Messages[0].from_address, tokenContract.address);
    expectAddressEquality(flushL2Messages[0].to_address, starknetBridge.address);

    // Consume transfering tokens on L1
    starknetBridge = starknetBridge.connect(l1Recipient);
    tx = await starknetBridge.bridgeTokensFromL2(tokenContract.address, l1Recipient.address, BigNumber.from(amount));
    rec = await tx.wait();

    balanceOfRandom = await bridgedERC20.balanceOf(l1Recipient.address);
    expect(balanceOfRandom).to.be.eq(BigNumber.from(amount));

    /**
     * Transfer tokens back to l2
     */

    await starknetBridge.bridgeTokensToL2withL2Address(
      tokenContract.address,
      l2recipient.address,
      BigNumber.from(amount),
    );

    balanceOfRandom = await bridgedERC20.balanceOf(l1Recipient.address);
    expect(balanceOfRandom).to.be.eq(0);

    /**
     * Check if L2 balance increased after the deposit
     */

    let l2RecipientBalance = await tokenContract.call("balanceOf", {
      account: l2recipient.address,
    });

    expect(uint256.uint256ToBN(l2RecipientBalance.balance)).to.deep.equal(0);

    /**
     * Flushing the L1 messages so that they can be consumed by the L2.
     */

    const flushL1Response = await starknet.devnet.flush();
    const flushL1Messages = flushL1Response.consumed_messages.from_l1;
    expect(flushL1Messages).to.have.a.lengthOf(1);
    expect(flushL1Response.consumed_messages.from_l2).to.be.empty;

    expectAddressEquality(flushL1Messages[0].args.from_address, starknetBridge.address);
    expectAddressEquality(flushL1Messages[0].args.to_address, tokenContract.address);
    expectAddressEquality(flushL1Messages[0].address, mockStarknetMessaging.address);

    l2RecipientBalance = await tokenContract.call("balanceOf", {
      account: l2recipient.address,
    });

    expect(uint256.uint256ToBN(l2RecipientBalance.balance)).to.be.eq(amount);
  });
});
