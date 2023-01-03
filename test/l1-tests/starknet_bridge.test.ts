import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

// type Create2Options = {
//   from: string;
//   salt: ethers.Arrayish;
//   initCode?: ethers.Arrayish;
//   initCodeHash: ethers.Arrayish;
// };

let saltHex = "0x0563b71ac29b54ef78bbfdB3FBF0338441D3948c573621E7824f9DbC1cE23d56"; // just some random L2 account

describe("Test utils", () => {
  async function deployContracts() {
    const bridgeUtilsFactory = await ethers.getContractFactory("BridgeUtils");
    const bridgeUtils = await bridgeUtilsFactory.deploy();

    const [deployer] = await ethers.getSigners();
    const deployerFactory = await ethers.getContractFactory("StarkNetERC20Bridge", {
      libraries: {
        "contracts/l1-contracts/BridgeUtils.sol:BridgeUtils": bridgeUtils.address,
      },
    });
    const starknetBridge = await deployerFactory.deploy();

    return { deployer, starknetBridge, bridgeUtils };
  }

  it("Test predicting deployed address", async () => {
    const { deployer, starknetBridge, bridgeUtils } = await loadFixture(deployContracts);

    let baseAccount = await starknetBridge.baseAccount();

    const byteCodeHash = ethers.utils.solidityKeccak256(
      ["bytes", "bytes20", "bytes"],
      ["0x3d602d80600a3d3981f3363d3d373d3d3d363d73", baseAccount, "0x5af43d82803e903d91602b57fd5bf3"],
    );
    console.log("ByteCodeHash", byteCodeHash);

    let create2PredictedAddress = ethers.utils.getCreate2Address(starknetBridge.address, saltHex, byteCodeHash);
    console.log("Future create2 Address", create2PredictedAddress);

    let erc20InstanceAddress = await starknetBridge.callStatic.createERC20(
      deployer.address,
      saltHex,
      "TOKEN2",
      "TKN2",
      { gasLimit: 1000000 },
    );
    console.log("Deployed ERC20 contract to", erc20InstanceAddress);
    expect(erc20InstanceAddress).to.equal(create2PredictedAddress);

    let contractAddressFromContract = await bridgeUtils.computeAddress(baseAccount, starknetBridge.address, saltHex);
    console.log("Address from contract", contractAddressFromContract);

    expect(contractAddressFromContract).to.equal(create2PredictedAddress);
  });

  it("Test string to uint", async () => {
    const { deployer, starknetBridge, bridgeUtils } = await loadFixture(deployContracts);

    let num = await bridgeUtils.strToUint("TEST");
    expect(num.toNumber()).to.eq(1413829460);

    num = await bridgeUtils.strToUint("test");
    expect(num.toNumber()).to.eq(1952805748);
  });
});

describe("Test deployed token functionality", () => {
  let erc20InstanceAddress: string;

  async function deployContracts() {
    const [deployer, user] = await ethers.getSigners();

    const bridgeUtilsFactory = await ethers.getContractFactory("BridgeUtils");
    const bridgeUtils = await bridgeUtilsFactory.deploy();

    const deployerFactory = await ethers.getContractFactory("StarkNetERC20Bridge", {
      libraries: {
        "contracts/l1-contracts/BridgeUtils.sol:BridgeUtils": bridgeUtils.address,
      },
    });
    const starknetBridge = await deployerFactory.deploy();

    erc20InstanceAddress = await starknetBridge.callStatic.createERC20(deployer.address, saltHex, "TOKEN1", "TKN1", {
      gasLimit: 3000000,
    });
    // console.log("Deployed ERC20 contract to", erc20InstanceAddress);
    let res = await starknetBridge.createERC20(deployer.address, saltHex, "TOKEN1", "TKN1", { gasLimit: 1000000 });
    // console.log("Deployment res", res);

    const tokenFactory = await ethers.getContractFactory("BridgedERC20");
    const tokenInstance = tokenFactory.attach(erc20InstanceAddress).connect(deployer);

    return { deployer, user, tokenInstance };
  }

  describe("Mint", async () => {
    it("Should mint some tokens", async () => {
      const { deployer, user, tokenInstance } = await loadFixture(deployContracts);

      let code = await ethers.provider.getCode(erc20InstanceAddress);
      // console.log("Address code", code);

      const toMint = ethers.utils.parseEther("1");

      await tokenInstance.mint(user.address, toMint, { gasLimit: 1000000 });
      let res = await tokenInstance.totalSupply();
      // console.log("Total Supply", res);
      expect(await tokenInstance.totalSupply()).to.eq(toMint);
    });
  });
});
