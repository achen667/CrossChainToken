// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMyToken} from "./interface/IMyToken.sol";

contract Vault {
    IMyToken public immutable i_myToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IMyToken _myToken) {
        i_myToken = _myToken;
    }

    receive() external payable {}

    function deposit() external payable {
        i_myToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        i_myToken.burn(msg.sender, _amount);

        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }
}
