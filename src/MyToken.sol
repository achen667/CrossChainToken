// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MyToken is ERC20, Ownable, AccessControl {
    bytes32 public constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");

    constructor() Ownable(msg.sender) ERC20("CrossChainToken", "CCT1") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINT_AND_BURN_ROLE, msg.sender);
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mint(to, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _burn(from, amount);
    }

    function grantMintAndBurnRole(address _address) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _address);
    }
}
