# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.0 (access/ownable.cairo)

%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

#
# Events
#

@event
func L1InstanceCreated():
end

@event
func TokensBridgedToL1(l1_recipient : felt, amount : Uint256):
end

@event
func TokensBridgedFromL1(l2_recipient : felt, amount : Uint256):
end

#
# Storage
#

@storage_var
func Bridgable_bridge() -> (bridge : felt):
end

namespace Bridgable:
    #
    # Constructor
    #

    func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        bridge : felt
    ):
        Bridgable_bridge.write(bridge)
        return ()
    end

    #
    # Protector (Modifier)
    #

    #
    # Public
    #

    func bridge{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        bridge : felt
    ):
        let (bridge) = Bridgable_bridge.read()
        return (bridge=bridge)
    end

    func create_l1_instance{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        name : felt, symbol : felt
    ):
        alloc_locals
        let (message_payload : felt*) = alloc()
        let (bridge) = Bridgable_bridge.read()
        assert message_payload[0] = name
        assert message_payload[1] = symbol
        send_message_to_l1(to_address=bridge, payload_size=2, payload=message_payload)
        L1InstanceCreated.emit()
        return ()
    end

    func bridge_tokens_to_l1{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        l1_recipient : felt, amount : Uint256
    ):
        alloc_locals
        let (message_payload : felt*) = alloc()
        let (caller) = get_caller_address()

        let (bridge) = Bridgable_bridge.read()
        assert message_payload[0] = l1_recipient
        assert message_payload[1] = amount.low
        assert message_payload[2] = amount.high
        send_message_to_l1(to_address=bridge, payload_size=3, payload=message_payload)
        TokensBridgedToL1.emit(l1_recipient, amount)
        return ()
    end

    func bridge_tokens_from_l1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_address : felt, l2_recipient : felt, amount : Uint256
    ):
        # check l1 message sender?
        let (bridge) = Bridgable_bridge.read()
        with_attr error_message("message-not-from-bridge"):
            assert from_address = bridge
        end

        TokensBridgedFromL1.emit(l2_recipient, amount)

        return ()
    end

    #
    # Internal
    #
end
