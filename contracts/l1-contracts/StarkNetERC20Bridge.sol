// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

import "./BridgedERC20.sol";

/**
 * Responsible for deploying new ERC20 contracts via CREATE2
 */
contract StarkNetERC20Bridge is Context {
    address public baseAccount;
    IStarknetCore starknetCore;

    // TODO: Consider removing for cheaper gas
    mapping(address => uint256) public l2Addresses;
    mapping(uint256 => address) public l1Addresses;

    uint256 private BRIDGE_FROM_L1_SELECTOR =
        1518189695498240477520172160170819975628670462807774879863606026550662793198;

    /**
     * Creates base Account for contracts
     */
    constructor() {
        baseAccount = address(new BridgedERC20{ salt: keccak256("V0.1") }());
        BridgedERC20(baseAccount).init(address(this), "STAB", "STAB");
        // This should be either configurable or changable by some address
        starknetCore = IStarknetCore(0xde29d060D45901Fb19ED6C6e959EB22d8626708e);
    }

    // TODO: minting should only be possible by the bridge
    function createERC20(
        address _deployer,
        uint256 tokenL2Address,
        string memory name,
        string memory symbol
    ) public returns (address) {
        // bytes32 salt = keccak256(abi.encodePacked(_deployer));
        bytes32 salt = bytes32(tokenL2Address);
        address payable clone = createCloneCreate2(salt);
        // Todo, replace deployer with the factory address
        BridgedERC20(clone).init(_deployer, name, symbol);
        return clone;
    }

    /**
     * Modified https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol#L30
     * to support Create2.
     * @param _salt Salt for CREATE2
     */
    function createCloneCreate2(bytes32 _salt) internal returns (address payable result) {
        bytes20 targetBytes = bytes20(baseAccount);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create2(0, clone, 0x37, _salt)
        }
        return result;
    }

    function createL1Instance(uint256 tokenL2Address, string calldata tokenName, string calldata tokenSymbol) public {
        uint256[] memory payload = new uint256[](2);
        // tokenName and Symbol are upto 32 bytes
        payload[0] = strToUint(tokenName);
        payload[1] = strToUint(tokenSymbol);
        // Consume the message from the StarkNet core contract.
        // This will revert the (Ethereum) transaction if the message does not exist.
        starknetCore.consumeMessageFromL2(tokenL2Address, payload);
        address createdToken = createERC20(address(this), tokenL2Address, tokenName, tokenSymbol);
        l2Addresses[createdToken] = tokenL2Address;
        l1Addresses[tokenL2Address] = createdToken;
        // TODO: Post an created token event
    }

    // Use if the string conversion did not work (consider removing?)
    function createL1InstanceWithUintName(uint256 tokenL2Address, uint256 tokenName, uint256 tokenSymbol) public {
        uint256[] memory payload = new uint256[](2);
        payload[0] = tokenName;
        payload[1] = tokenSymbol;
        // Consume the message from the StarkNet core contract.
        // This will revert the (Ethereum) transaction if the message does not exist.
        starknetCore.consumeMessageFromL2(tokenL2Address, payload);
        address createdToken = createERC20(
            address(this),
            tokenL2Address,
            uintToString(tokenName),
            uintToString(tokenSymbol)
        );
        l2Addresses[createdToken] = tokenL2Address;
        l1Addresses[tokenL2Address] = createdToken;
    }

    function bridgeTokensFromL2(uint256 tokenL2Address, uint256 tokenReceiver, uint256 tokenAmount) public {
        require(l1Addresses[tokenL2Address] != address(0), "No L1 token initiated for this l2 address");
        uint256[] memory payload = new uint256[](3);
        payload[0] = tokenReceiver;
        (payload[1], payload[2]) = toSplitUint(tokenAmount);
        // Consume the message from the StarkNet core contract.
        // This will revert the (Ethereum) transaction if the message does not exist.
        starknetCore.consumeMessageFromL2(tokenL2Address, payload);

        // Possible to also computer address, but it should be in storage
        // address tokenL1Address = computeAddress(tokenL2Address);

        address tokenL1Address = l1Addresses[tokenL2Address];
        // TODO: check token is deployed, but this will fail if not
        bool success = IERC20(tokenL1Address).mint(address(uint160(tokenReceiver)), tokenAmount);
        require(success, "Minting L1 tokens failed");
    }

    function bridgeTokensToL2(uint256 tokenL2Address, uint256 l2Recipient, uint256 amount) public {
        require(l1Addresses[tokenL2Address] != address(0), "No L1 token initiated for this l2 address");
        uint256[] memory payload = new uint256[](3);
        payload[0] = l2Recipient;
        (payload[1], payload[2]) = toSplitUint(amount);

        starknetCore.sendMessageToL2(tokenL2Address, BRIDGE_FROM_L1_SELECTOR, payload);

        // address tokenL1Address = computeAddress(tokenL2Address);
        address tokenL1Address = l1Addresses[tokenL2Address];

        // If we remove storage, transaction will fail here after not finding ERC20
        bool success = IERC20(tokenL1Address).burn(_msgSender(), amount);
        require(success, "Burning on L1 Failed");
    }

    function uintToString(uint256 v) public pure returns (string memory str) {
        return Strings.toString(v);
    }

    function strToUint(string memory text) public pure returns (uint256 res) {
        bytes32 stringInBytes32 = bytes32(bytes(text));
        uint256 strLen = bytes(text).length; // TODO: cannot be above 32
        require(strLen <= 32, "String cannot be longer than 32");

        uint256 shift = 256 - 8 * strLen;

        uint256 stringInUint256;
        assembly {
            stringInUint256 := shr(shift, stringInBytes32)
        }
        return stringInUint256;
    }

    function computeAddress(uint256 tokenL2Address) public view returns (address tokenL1Address) {
        bytes20 targetBytes = bytes20(baseAccount);
        bytes32 baseCodeHash;
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            baseCodeHash := keccak256(clone, 0x37)
        }
        tokenL1Address = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), bytes32(tokenL2Address), baseCodeHash))))
        );
    }

    function toSplitUint(uint256 value) internal pure returns (uint256, uint256) {
        uint256 low = value & ((1 << 128) - 1);
        uint256 high = value >> 128;
        return (low, high);
    }
}
