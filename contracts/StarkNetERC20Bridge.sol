// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IStarknetCore.sol";
import "./interfaces/IERC20.sol";

/**
 * @notice A mintable ERC20
 */
contract FactoryERC20 is IERC20, Context {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    address public _deployer;
    string private _name;
    string private _symbol;

    bool private _initDone = false;

    constructor() {}

    function init(
        address deployer_,
        string memory name_,
        string memory symbol_
    ) public {
        require(_initDone == false, "Can only init once");
        _initDone = true;
        _deployer = deployer_;
        _name = string.concat("Wrapped StarkNet ", name_);
        _symbol = string.concat("wsn", symbol_);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function mint(address to, uint256 amount) external returns (bool) {
        require(_deployer == msg.sender, "Only deployer can mint");
        _mint(to, amount);
        return true;
    }

    function burn(address account, uint256 amount) external returns (bool) {
        require(_deployer == msg.sender, "Only deployer can burn");
        _burn(account, amount);
        return true;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {}
}

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
        baseAccount = address(new FactoryERC20{ salt: keccak256("V0.1") }());
        FactoryERC20(baseAccount).init(address(this), "STAB", "STAB");
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
        FactoryERC20(clone).init(_deployer, name, symbol);
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

    function createL1Instance(
        uint256 tokenL2Address,
        string calldata tokenName,
        string calldata tokenSymbol
    ) public {
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
    function createL1InstanceWithUintName(
        uint256 tokenL2Address,
        uint256 tokenName,
        uint256 tokenSymbol
    ) public {
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

    function bridgeTokensFromL2(
        uint256 tokenL2Address,
        uint256 tokenReceiver,
        uint256 tokenAmount
    ) public {
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

    function bridgeTokensToL2(
        uint256 tokenL2Address,
        uint256 l2Recipient,
        uint256 amount
    ) public {
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
