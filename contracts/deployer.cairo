%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.uint256 import Uint256

# Define a storage variable for the salt.
@storage_var
func salt() -> (value : felt):
end

@storage_var
func deployable_class_hash() -> (value : felt):
end

@storage_var
func _bridge() -> (value : felt):
end

@event
func contract_deployed(contract_address : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    class_hash : felt, bridge : felt
):
    deployable_class_hash.write(value=class_hash)
    _bridge.write(value=bridge)
    return ()
end

@external
func deploy_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    name : felt, symbol : felt, decimals : felt, initial_supply : Uint256, recipient : felt
):
    let (current_salt) = salt.read()
    let (bridge) = _bridge.read()
    let (class_hash) = deployable_class_hash.read()
    let (contract_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=7,
        constructor_calldata=cast(new (name, symbol, decimals, initial_supply.low, initial_supply.high, recipient, bridge), felt*),
        deploy_from_zero=0,
    )
    salt.write(value=current_salt + 1)

    contract_deployed.emit(contract_address=contract_address)
    return ()
end
