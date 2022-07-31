import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { FactoryERC20__factory, StarkNetERC20Bridge__factory } from "../typechain";

// type Create2Options = {
//   from: string;
//   salt: ethers.Arrayish;
//   initCode?: ethers.Arrayish;
//   initCodeHash: ethers.Arrayish;
// };

let saltHex = "0x0563b71ac29b54ef78bbfdB3FBF0338441D3948c573621E7824f9DbC1cE23d56"; // just some random L2 account

chai.use(solidity);
const { expect } = chai;

describe("Test utils", () => {
  it("Test predicting deployed address", async () => {
    const [deployer] = await ethers.getSigners();
    const deployerFactory = new StarkNetERC20Bridge__factory(deployer);
    const deployerContract = await deployerFactory.deploy();

    let deployerFactoryAddress = deployerContract.address;

    let baseAccount = await deployerContract.baseAccount();
    console.log("Base Account", baseAccount);

    const byteCodeHash = ethers.utils.solidityKeccak256(
      ["bytes", "bytes20", "bytes"],
      ["0x3d602d80600a3d3981f3363d3d373d3d3d363d73", baseAccount, "0x5af43d82803e903d91602b57fd5bf3"],
    );
    console.log("ByteCodeHash", byteCodeHash);

    let create2PredictedAddress = ethers.utils.getCreate2Address(deployerContract.address, saltHex, byteCodeHash);
    console.log("Future create2 Address", create2PredictedAddress);

    let erc20InstanceAddress = await deployerContract.callStatic.createERC20(
      deployer.address,
      saltHex,
      "TOKEN2",
      "TKN2",
      { gasLimit: 1000000 },
    );
    console.log("Deployed ERC20 contract to", erc20InstanceAddress);

    let contractAddressFromContract = await deployerContract.computeAddress(saltHex);
    console.log("Address from contract", contractAddressFromContract);
  });

  it("Test string to uint", async () => {
    const [deployer] = await ethers.getSigners();
    const deployerFactory = new StarkNetERC20Bridge__factory(deployer);
    const deployerContract = await deployerFactory.deploy();

    let deployerFactoryAddress = deployerContract.address;

    let num = await deployerContract.strToUint("TEST");
    console.log("TEST: ", num);

    num = await deployerContract.strToUint("test");
    console.log("test: ", num);
  });
});

describe("Token", () => {
  let deployerFactoryAddress: string;
  let erc20InstanceAddress: string;

  beforeEach(async () => {
    // Deploy ERC20 factory
    const [deployer] = await ethers.getSigners();
    const deployerFactory = new StarkNetERC20Bridge__factory(deployer);
    const deployerContract = await deployerFactory.deploy();

    deployerFactoryAddress = deployerContract.address;

    erc20InstanceAddress = await deployerContract.callStatic.createERC20(deployer.address, saltHex, "TOKEN1", "TKN1", {
      gasLimit: 3000000,
    });
    console.log("Deployed ERC20 contract to", erc20InstanceAddress);
    let res = await deployerContract.createERC20(deployer.address, saltHex, "TOKEN1", "TKN1", { gasLimit: 1000000 });
    console.log("Deployment res", res);

    // Deploy ERC20 insatce
  });
  describe("Mint", async () => {
    it("Should mint some tokens", async () => {
      console.log("mint");
      const [deployer, user] = await ethers.getSigners();

      let code = await ethers.provider.getCode(erc20InstanceAddress);
      console.log("Address code", code);

      const tokenInstance = new FactoryERC20__factory(deployer).attach(erc20InstanceAddress);
      const toMint = ethers.utils.parseEther("1");

      await tokenInstance.mint(user.address, toMint, { gasLimit: 1000000 });
      let res = await tokenInstance.totalSupply();
      console.log("Total Supply", res);
      // expect(await tokenInstance.totalSupply()).to.eq(toMint);
    });
  });
});
