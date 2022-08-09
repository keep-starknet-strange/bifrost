%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.bool import TRUE

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.library import ERC20

from contracts.Bridgable import Bridgable

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    name : felt, symbol : felt, decimals : felt, initial_supply : Uint256, recipient : felt, bridge
):
    ERC20.initializer(name, symbol, decimals)
    ERC20._mint(recipient, initial_supply)
    Ownable.initializer(recipient)
    Bridgable.initializer(bridge)
    return ()
end

#
# Getters
#

@view
func bridge{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (bridge : felt):
    let (bridge) = Bridgable.bridge()
    return (bridge)
end

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC20.name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20.symbol()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    totalSupply : Uint256
):
    let (totalSupply : Uint256) = ERC20.total_supply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    let (decimals) = ERC20.decimals()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : Uint256):
    let (balance : Uint256) = ERC20.balance_of(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : Uint256):
    let (remaining : Uint256) = ERC20.allowance(owner, spender)
    return (remaining)
end

@view
func owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (owner : felt):
    let (owner : felt) = Ownable.owner()
    return (owner)
end

#
# Externals
#

@external
func faucet{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    success : felt
):
    let amount : Uint256 = Uint256(100 * 1000000000000000000, 0)
    let (caller) = get_caller_address()
    ERC20._mint(caller, amount)
    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
) -> (success : felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : Uint256
) -> (success : felt):
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : Uint256
) -> (success : felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, added_value : Uint256
) -> (success : felt):
    ERC20.increase_allowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, subtracted_value : Uint256
) -> (success : felt):
    ERC20.decrease_allowance(spender, subtracted_value)
    return (TRUE)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, amount : Uint256
):
    Ownable.assert_only_owner()
    ERC20._mint(to, amount)
    return ()
end

@external
func create_l1_instance{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    let (_name) = name()
    let (_symbol) = symbol()
    Bridgable.create_l1_instance(_name, _symbol)
    return ()
end

@external
func bridge_tokens_to_l1{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
    l1_recipient : felt, amount : Uint256
):
    let (caller) = get_caller_address()
    Bridgable.bridge_tokens_to_l1(l1_recipient, amount)

    # The Bridgable only sends a message, we can chose to lock or to burn, in this case we burn
    ERC20._burn(caller, amount)
    return ()
end

@l1_handler
func bridge_from_l1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    from_address : felt, l2_recipient : felt, amount_low : felt, amount_high : felt
):
    let amount = Uint256(low=amount_low, high=amount_high)
    Bridgable.bridge_tokens_from_l1(from_address, l2_recipient, amount)
    ERC20._mint(l2_recipient, amount)

    return ()
end
