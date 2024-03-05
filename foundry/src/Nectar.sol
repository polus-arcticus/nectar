// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import "forge-std/console.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {ExampleClient} from "./ExampleClient.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

contract Nectar is BaseHook, ExampleClient {
    uint24 internal fee;
    using CurrencyLibrary for Currency;
    uint256 constant WITHDRAWAL_FEE_BIPS = 40; // 40/10000 = 0.4%
    uint256 constant SWAP_FEE_BIPS = 55; // 55/10000 = 0.55%
    uint256 constant TOTAL_BIPS = 10000;

    using PoolIdLibrary for PoolKey;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    constructor(
        IPoolManager _poolManager,
        address _jobManagerAddress
    ) BaseHook(_poolManager) ExampleClient(_jobManagerAddress) {}

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true, // after swap
                beforeDonate: false,
                afterDonate: true, // after donate
                noOp: false,
                accessLock: true
            });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4) {
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        (Currency feeCurrency, uint256 outputAmount) = (params.zeroForOne)
            ? (key.currency1, uint128(-amount1))
            : (key.currency0, uint128(-amount0));

        uint256 feeAmount = (outputAmount * SWAP_FEE_BIPS) / TOTAL_BIPS;
        console.log("feeamount", feeAmount);
        poolManager.take(feeCurrency, address(this), feeAmount);
        if (feeCurrency.balanceOfSelf() > jobPrices[feeCurrency]) {
            runCowsay(jobArgs.message);
        }
        /*
        // check fees
        // if fees >= edge compute job price
        */
        return BaseHook.afterSwap.selector;
    }

    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.afterDonate.selector;
    }

    function setFee(uint24 _fee) external {
        fee = _fee;
    }

    function getFee(address, PoolKey calldata) public view returns (uint24) {
        return fee;
    }

    //function runJob() internal {}
}
