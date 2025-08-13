// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

import {MyToken} from "../src/MyToken.sol";
import {MyTokenPool} from "../src/MyTokenPool.sol";
import {Vault} from "../src/Vault.sol";

import {IMyToken} from "../src/interface/IMyToken.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (MyToken token, MyTokenPool pool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);

        /*
        s_networkDetails[11155111] = NetworkDetails({
            chainSelector: 16015286601757825753,
            routerAddress: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            wrappedNativeAddress: 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534,
            ccipBnMAddress: 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05,
            ccipLnMAddress: 0x466D489b6d36E7E3b824ef491C225F5830E81cC1,
            rmnProxyAddress: 0xba3f6251de62dED61Ff98590cB2fDf6871FbB991,
            registryModuleOwnerCustomAddress: 0x62e731218d0D47305aba2BE3751E7EE9E5520790,
            tokenAdminRegistryAddress: 0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82
        });
        */
        vm.startBroadcast();
        token = new MyToken();
        pool = new MyTokenPool(
            IERC20(address(token)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        token.grantMintAndBurnRole(address(pool));
        RegistryModuleOwnerCustom(
            networkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(token),
            address(pool)
        );
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address myToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IMyToken(myToken));
        IMyToken(myToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
