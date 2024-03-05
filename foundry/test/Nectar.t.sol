// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {Nectar} from "../src/Nectar.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {FeeLibrary} from "v4-core/src/libraries/FeeLibrary.sol";
import {JobArgs} from "../src/ExampleClient.sol";

contract NectarTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    Nectar nectar;
    PoolId poolId;

    address jobManager = makeAddr("JobManager");

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG |
                Hooks.AFTER_DONATE_FLAG |
                Hooks.ACCESS_LOCK_FLAG
        );
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(Nectar).creationCode,
            abi.encode(address(manager), jobManager)
        );
        nectar = new Nectar{salt: salt}(
            IPoolManager(address(manager)),
            jobManager
        );
        require(
            address(nectar) == hookAddress,
            "NectarTest: hook address mismatch"
        );
        // Create the pool
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(nectar))
        });
        vm.startPrank(jobManager);

        nectar.setJobPrice(currency0, 1 ether);
        nectar.setJobPrice(currency1, 1 ether);
        JobArgs memory jobArgs = JobArgs("hello");
        nectar.setJobArgs(jobArgs);
        vm.stopPrank();

        poolId = key.toId();
        initializeRouter.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);
        console.log("hmmm");

        // Provide liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether),
            ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether),
            ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                10 ether
            ),
            ZERO_BYTES
        );
    }

    function testNectarHooks() public {
        // positions were created in setup()
        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = 1e18;
        BalanceDelta swapDelta = swap(
            key,
            zeroForOne,
            amountSpecified,
            ZERO_BYTES
        );
        // ------------------- //

        assertEq(int256(swapDelta.amount0()), amountSpecified);
    }

    function testLiquidityHooks() public {
        // positions were created in setup()

        // remove liquidity
        int256 liquidityDelta = -1e18;
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(-60, 60, liquidityDelta),
            ZERO_BYTES
        );
    }
}
