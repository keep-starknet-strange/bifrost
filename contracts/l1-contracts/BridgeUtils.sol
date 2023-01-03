// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

library BridgeUtils {
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

    function computeAddress(
        address baseAccount,
        address factoryAddress,
        uint256 tokenL2Address
    ) public pure returns (address tokenL1Address) {
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
            uint160(
                uint256(keccak256(abi.encodePacked(hex"ff", factoryAddress, bytes32(tokenL2Address), baseCodeHash)))
            )
        );
    }

    function toSplitUint(uint256 value) internal pure returns (uint256, uint256) {
        uint256 low = value & ((1 << 128) - 1);
        uint256 high = value >> 128;
        return (low, high);
    }
}
