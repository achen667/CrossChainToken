// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console, Test} from "forge-std/Test.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {MyToken} from "../src/MyToken.sol";

import {MyTokenPool} from "../src/MyTokenPool.sol";

import {Vault} from "../src/Vault.sol";
import {IMyToken} from "../src/interface/IMyToken.sol";

import {TokenAndPoolDeployer, VaultDeployer} from "../script/Deployer.s.sol";

// Tests to include
// Test you can bridge tokens - check the balance is correct
// test you can bridge a portion of tokens - check balances are correct
// test you can bridge and then bridge back all balance - check balances
// test you can bridge and then bridge back a portion - check balances
contract CrossChainTest is Test {
    address public owner = makeAddr("owner");
    address alice = makeAddr("alice");
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 public SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    MyToken destMyToken;
    MyToken sourceMyToken;

    MyTokenPool destPool;
    MyTokenPool sourcePool;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryarbSepolia;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;

    Vault vault;

    TokenAndPoolDeployer tokenAndPoolDeployer;
    VaultDeployer vaultDeployer;

    function setUp() public {
        tokenAndPoolDeployer = new TokenAndPoolDeployer();
        vaultDeployer = new VaultDeployer();
        // 1. Setup the Sepolia and arb forks
        sepoliaFork = vm.createSelectFork("eth");
        arbSepoliaFork = vm.createFork("arb");

        //Pin this deployed contract into all forks
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        //2. Deploy and configure on the source chain: Sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.startPrank(owner);
        sourceMyToken = new MyToken();
        console.log("source rebase token address");
        console.log(address(sourceMyToken));
        console.log("Deploying token pool on Sepolia");
        sourcePool = new MyTokenPool(
            IERC20(address(sourceMyToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        // deploy the vault
        vault = new Vault(IMyToken(address(sourceMyToken)));
        // add rewards to the vault
        vm.deal(address(vault), 1e18);
        // Set pool on the token contract for permissions on Sepolia
        sourceMyToken.grantMintAndBurnRole(address(sourcePool));
        sourceMyToken.grantMintAndBurnRole(address(vault));
        // Claim role on Sepolia
        registryModuleOwnerCustomSepolia = RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(
            address(sourceMyToken)
        );
        // Accept role on Sepolia
        tokenAdminRegistrySepolia = TokenAdminRegistry(
            sepoliaNetworkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistrySepolia.acceptAdminRole(address(sourceMyToken));
        // Link token to pool in the token admin registry on Sepolia
        tokenAdminRegistrySepolia.setPool(
            address(sourceMyToken),
            address(sourcePool)
        );
        vm.stopPrank();

        //3. Deploy and configure on the destination chain: Arbitrum
        //Deploy the token contract on Arbitrum
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);

        console.log("Deploying token on Arbitrum");
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        destMyToken = new MyToken();
        console.log("dest rebase token address");
        console.log(address(destMyToken));
        // Deploy the token pool on Arbitrum
        console.log("Deploying token pool on Arbitrum");
        destPool = new MyTokenPool(
            IERC20(address(destMyToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        //Set pool on the token contract for permissions on Arbitrum
        destMyToken.grantMintAndBurnRole(address(destPool));
        // Claim role on Arbitrum
        registryModuleOwnerCustomarbSepolia = RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        );
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(
            address(destMyToken)
        );
        // Accept role on Arbitrum
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(
            arbSepoliaNetworkDetails.tokenAdminRegistryAddress
        );
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(destMyToken));
        // Link token to pool in the token admin registry on Arbitrum
        tokenAdminRegistryarbSepolia.setPool(
            address(destMyToken),
            address(destPool)
        );
        vm.stopPrank();
    }

    function configureTokenPool(
        uint256 fork,
        TokenPool localPool,
        TokenPool remotePool,
        IMyToken remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(address(remotePool));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddresses[0],
            remoteTokenAddress: abi.encode(address(remoteToken)),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });

        localPool.applyChainUpdates(chains);
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        MyToken localToken,
        MyToken remoteToken
    ) public {
        // Create the message to send tokens cross-chain
        vm.selectFork(localFork);
        vm.startPrank(alice);
        Client.EVMTokenAmount[]
            memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        tokenToSendDetails[0] = tokenAmount;
        // Approve the router to burn tokens on users behalf
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            amountToBridge
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(alice), // we need to encode the address to bytes
            data: "", // We don't need any data for this example
            tokenAmounts: tokenToSendDetails, // this needs to be of type EVMTokenAmount[] as you could send multiple tokens
            extraArgs: "", // We don't need any extra args for this example
            feeToken: localNetworkDetails.linkAddress // The token used to pay for the fee
        });
        // Get and approve the fees
        vm.stopPrank();
        // Give the user the fee amount of LINK
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            alice,
            IRouterClient(localNetworkDetails.routerAddress).getFee(
                remoteNetworkDetails.chainSelector,
                message
            )
        );
        vm.startPrank(alice);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(
                remoteNetworkDetails.chainSelector,
                message
            )
        ); // Approve the fee
        // log the values before bridging
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(
            alice
        );
        console.log("Local balance before bridge: %d", balanceBeforeBridge);

        IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector,
            message
        ); // Send the message
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken))
            .balanceOf(alice);
        console.log("Local balance after bridge: %d", sourceBalanceAfterBridge);
        assertEq(
            sourceBalanceAfterBridge,
            balanceBeforeBridge - amountToBridge
        );
        vm.stopPrank();

        vm.selectFork(remoteFork);
        // Pretend it takes 15 minutes to bridge the tokens
        vm.warp(block.timestamp + 900);
        // get initial balance on Arbitrum
        uint256 initialArbBalance = IERC20(address(remoteToken)).balanceOf(
            alice
        );
        console.log("Remote balance before bridge: %d", initialArbBalance);
        vm.selectFork(localFork); // in the latest version of chainlink-local, it assumes you are currently on the local fork before calling switchChainAndRouteMessage
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        uint256 destBalance = IERC20(address(remoteToken)).balanceOf(alice);
        console.log("Remote balance after bridge: %d", destBalance);
        assertEq(destBalance, initialArbBalance + amountToBridge);
    }

    function testBridgeAllTokens() public {
        configureTokenPool(
            sepoliaFork,
            sourcePool,
            destPool,
            IMyToken(address(destMyToken)),
            arbSepoliaNetworkDetails
        );
        configureTokenPool(
            arbSepoliaFork,
            destPool,
            sourcePool,
            IMyToken(address(sourceMyToken)),
            sepoliaNetworkDetails
        );
        // We are working on the source chain (Sepolia)
        vm.selectFork(sepoliaFork);
        // Pretend a user is interacting with the protocol
        // Give the user some ETH
        vm.deal(alice, SEND_VALUE);
        vm.startPrank(alice);
        // Deposit to the vault and receive tokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        // bridge the tokens
        console.log("Bridging %d tokens", SEND_VALUE);
        uint256 startBalance = IERC20(address(sourceMyToken)).balanceOf(alice);
        assertEq(startBalance, SEND_VALUE);
        vm.stopPrank();
        // bridge ALL TOKENS to the destination chain
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceMyToken,
            destMyToken
        );
    }

    function testBridgeAllTokensBack() public {
        configureTokenPool(
            sepoliaFork,
            sourcePool,
            destPool,
            IMyToken(address(destMyToken)),
            arbSepoliaNetworkDetails
        );
        configureTokenPool(
            arbSepoliaFork,
            destPool,
            sourcePool,
            IMyToken(address(sourceMyToken)),
            sepoliaNetworkDetails
        );
        // We are working on the source chain (Sepolia)
        vm.selectFork(sepoliaFork);
        // Pretend a user is interacting with the protocol
        // Give the user some ETH
        vm.deal(alice, SEND_VALUE);
        vm.startPrank(alice);
        // Deposit to the vault and receive tokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        // bridge the tokens
        console.log("Bridging %d tokens", SEND_VALUE);
        uint256 startBalance = IERC20(address(sourceMyToken)).balanceOf(alice);
        assertEq(startBalance, SEND_VALUE);
        vm.stopPrank();
        // bridge ALL TOKENS to the destination chain
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceMyToken,
            destMyToken
        );
        // bridge back ALL TOKENS to the source chain after 1 hour
        vm.selectFork(arbSepoliaFork);
        console.log(
            "User Balance Before Warp: %d",
            destMyToken.balanceOf(alice)
        );
        vm.warp(block.timestamp + 3600);
        console.log(
            "User Balance After Warp: %d",
            destMyToken.balanceOf(alice)
        );
        uint256 destBalance = IERC20(address(destMyToken)).balanceOf(alice);
        console.log("Amount bridging back %d tokens ", destBalance);
        bridgeTokens(
            destBalance,
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            destMyToken,
            sourceMyToken
        );
    }

    function testBridgeTwice() public {
        configureTokenPool(
            sepoliaFork,
            sourcePool,
            destPool,
            IMyToken(address(destMyToken)),
            arbSepoliaNetworkDetails
        );
        configureTokenPool(
            arbSepoliaFork,
            destPool,
            sourcePool,
            IMyToken(address(sourceMyToken)),
            sepoliaNetworkDetails
        );
        // We are working on the source chain (Sepolia)
        vm.selectFork(sepoliaFork);
        // Pretend a user is interacting with the protocol
        // Give the user some ETH
        vm.deal(alice, SEND_VALUE);
        vm.startPrank(alice);
        // Deposit to the vault and receive tokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        uint256 startBalance = IERC20(address(sourceMyToken)).balanceOf(alice);
        assertEq(startBalance, SEND_VALUE);
        vm.stopPrank();
        // bridge half tokens to the destination chain
        // bridge the tokens
        console.log(
            "Bridging %d tokens (first bridging event)",
            SEND_VALUE / 2
        );
        bridgeTokens(
            SEND_VALUE / 2,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceMyToken,
            destMyToken
        );
        // wait 1 hour for the interest to accrue
        vm.selectFork(sepoliaFork);
        vm.warp(block.timestamp + 3600);
        uint256 newSourceBalance = IERC20(address(sourceMyToken)).balanceOf(
            alice
        );
        // bridge the tokens
        console.log(
            "Bridging %d tokens (second bridging event)",
            newSourceBalance
        );
        bridgeTokens(
            newSourceBalance,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceMyToken,
            destMyToken
        );
        // bridge back ALL TOKENS to the source chain after 1 hour
        vm.selectFork(arbSepoliaFork);
        // wait an hour for the tokens to accrue interest on the destination chain
        console.log(
            "User Balance Before Warp: %d",
            destMyToken.balanceOf(alice)
        );
        vm.warp(block.timestamp + 3600);
        console.log(
            "User Balance After Warp: %d",
            destMyToken.balanceOf(alice)
        );
        uint256 destBalance = IERC20(address(destMyToken)).balanceOf(alice);
        console.log("Amount bridging back %d tokens ", destBalance);
        bridgeTokens(
            destBalance,
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            destMyToken,
            sourceMyToken
        );
    }
}
