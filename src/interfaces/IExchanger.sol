// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vault} from "../Vault.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IExchanger Interface
 * @dev Interface for exchanging ERC-20 tokens and native currency for a specific token and vice versa.
 */
interface IExchanger {
    /**
     * @dev Struct to represent fees as a fraction.
     */
    struct Fee {
        uint numerator;
        uint denominator;
    }

    /**
     * @dev Struct to represent exchange rates and associated fees.
     */
    struct Rate {
        Fee fee;
        uint baseRate;
    }

    // Errors
    error InvalidParams();
    error TokensNotAllowed(address fromToken, address toToken);
    error NotEnoughLiquidity(address token, uint amount);
    error NotSuccessTransferNative(address recipient, uint amount);

    // Events
    event TokenRateSet(IERC20 indexed token, Rate indexed rate);
    event NativeRateSet(Rate indexed rate);
    event Exchanged(address indexed token, address indexed to, uint amount);
    event ExchangedFrom(
        address indexed token,
        address indexed from,
        address to,
        uint amount
    );
    event Withdraw(address indexed token, address indexed to, uint amount);

    /**
     * @dev Get the exchange rate for a specific token.
     * @param token Address of the token.
     * @return rate The exchange rate for the token.
     */
    function getRate(address token) external view returns (Rate memory);

    /**
     * @dev Get the base token for the exchange.
     * @return The base token.
     */
    function getBaseToken() external view returns (IERC20);

    /**
     * @dev Get the vault where fees are sent.
     * @return The vault.
     */
    function getVault() external view returns (Vault);

    /**
     * @dev Calculate the fee and transfer amount for a specific exchange.
     * @param fromToken The token being provided.
     * @param toToken The token being requested.
     * @param amount The amount of `fromToken` being provided.
     * @return fee The fee for the exchange.
     * @return transferAmount The amount of `toToken` that will be received.
     */
    function calculateFee(
        address fromToken,
        address toToken,
        uint amount
    ) external view returns (uint fee, uint transferAmount);

    /**
     * @dev Execute an exchange.
     * @param fromToken The token being provided.
     * @param toToken The token being requested.
     * @param amount The amount of `fromToken` being provided.
     */
    function exchange(address fromToken, address toToken, uint amount) external;

    /**
     * @dev Remove the native currency exchange rate.
     */
    function removeNativeRate() external;

    /**
     * @dev Withdraw a specific amount of a token.
     * @param token The token to withdraw.
     * @param to The address to send the withdrawn tokens to.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(address token, address to, uint amount) external;

    /**
     * @dev Remove the exchange rate for a specific token.
     * @param token The token to remove the exchange rate for.
     */
    function removeTokenRate(IERC20 token) external;
}
