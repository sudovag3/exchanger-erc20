// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/IExchanger.sol";

/**
 * @title Exchanger Contract
 * @dev Implementation of the IExchanger interface for exchanging ERC-20 tokens and native currency.
 */
contract Exchanger is IExchanger, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Mapping of tokens to their exchange rates.
    mapping(IERC20 => Rate) private _tokenWhiteList;
    // Exchange rate for native currency.
    Rate private _nativeRate;
    // Vault to store fees.
    Vault _vault;
    // Base token for the exchange.
    IERC20 private _baseToken;

    /**
     * @dev Ensure that the tokens involved in the exchange are allowed.
     */
    modifier onlyAllowedTokens(address fromToken, address toToken) {
        if (
            ((fromToken == address(_baseToken) &&
                _tokenWhiteList[IERC20(toToken)].baseRate == 0) ||
                (toToken == address(_baseToken) &&
                    _tokenWhiteList[IERC20(fromToken)].baseRate == 0)) &&
            ((fromToken == address(0) || toToken == address(0)) &&
                _nativeRate.baseRate == 0)
        ) {
            revert TokensNotAllowed(fromToken, toToken);
        }
        _;
    }

    /**
     * @dev Constructor to set the base token and create a new vault.
     * @param baseToken Address of the base token.
     */
    constructor(address baseToken) Ownable() {
        _baseToken = IERC20(baseToken);
        _vault = new Vault(owner());
    }

    /**
     * @dev Set the exchange rate for a specific token.
     * @param token The token to set the rate for.
     * @param rate The exchange rate for the token.
     */
    function setTokenRate(IERC20 token, Rate memory rate) external onlyOwner {
        if (rate.fee.denominator == 0 || rate.baseRate == 0) {
            revert InvalidParams();
        }

        _tokenWhiteList[token] = rate;

        emit TokenRateSet(token, rate);
    }

    /**
     * @dev Set the exchange rate for native currency.
     * @param rate The exchange rate for native currency.
     */
    function setNativeRate(Rate memory rate) external onlyOwner {
        if (rate.fee.denominator == 0 || rate.baseRate == 0) {
            revert InvalidParams();
        }

        _nativeRate = rate;

        emit NativeRateSet(rate);
    }

    /**
     * @dev Remove the exchange rate for native currency.
     */
    function removeNativeRate() external onlyOwner {
        Rate memory emptyRate;
        _nativeRate = emptyRate;

        emit NativeRateSet(emptyRate);
    }

    /**
     * @dev Remove the exchange rate for a specific token.
     * @param token The token to remove the rate for.
     */
    function removeTokenRate(IERC20 token) external onlyOwner {
        Rate memory emptyRate;
        delete _tokenWhiteList[token];

        emit TokenRateSet(token, emptyRate);
    }

    /**
     * @dev Withdraw a specific amount of a token.
     * @param token The token to withdraw.
     * @param to The address to send the withdrawn tokens to.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(
        address token,
        address to,
        uint amount
    ) external onlyOwner {
        _withdraw(token, to, amount);
    }

    /**
     * @dev Execute an exchange.
     * @param fromToken The token being provided.
     * @param toToken The token being requested.
     * @param amount The amount of `fromToken` being provided.
     */
    function exchange(
        address fromToken,
        address toToken,
        uint amount
    ) external {
        (uint fee, uint transferAmount) = _calculateFee(
            fromToken,
            toToken,
            amount
        );

        _beforeExchange(fromToken, toToken, amount, transferAmount);

        _exchangeFrom(fromToken, msg.sender, address(this), amount);

        if (fromToken != address(_baseToken)) {
            _exchange(fromToken, address(_vault), fee);
        }
        _exchange(toToken, msg.sender, transferAmount);

        _afterExchange(fromToken, toToken, amount, transferAmount);
    }

    /**
     * @dev Receive function to handle incoming ether.
     */
    receive() external payable {
        (uint fee, uint transferAmount) = _calculateFee(
            address(0),
            address(_baseToken),
            msg.value
        );

        _beforeExchange(
            address(0),
            address(_baseToken),
            msg.value,
            transferAmount
        );

        _exchange(address(0), address(_vault), fee);

        _exchange(address(_baseToken), msg.sender, transferAmount);

        _afterExchange(
            address(0),
            address(_baseToken),
            msg.value,
            transferAmount
        );
    }

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
    ) external view returns (uint fee, uint transferAmount) {
        return _calculateFee(fromToken, toToken, amount);
    }

    /**
     * @dev Get the exchange rate for a specific token.
     * @param token Address of the token.
     * @return rate The exchange rate for the token.
     */
    function getRate(address token) external view returns (Rate memory) {
        return _tokenWhiteList[IERC20(token)];
    }

    /**
     * @dev Get the base token for the exchange.
     * @return The base token.
     */
    function getBaseToken() external view returns (IERC20) {
        return _baseToken;
    }

    /**
     * @dev Get the vault where fees are sent.
     * @return The vault.
     */
    function getVault() external view returns (Vault) {
        return _vault;
    }

    /**
     * @dev Get the exchange rate for native currency.
     * @return rate The exchange rate for native currency.
     */
    function getNativeRate() external view returns (Rate memory) {
        return _nativeRate;
    }

    function _getDecimals(address token) internal view returns (uint8) {
        if (token == address(0)) {
            return 18;
        } else {
            return ERC20(token).decimals();
        }
    }

    function _getLiquidity(address token) internal view returns (uint) {
        if (token == address(0)) {
            return address(this).balance;
        } else {
            return ERC20(token).balanceOf(address(this));
        }
    }

    function _exchangeFrom(
        address token,
        address from,
        address to,
        uint amount
    ) internal {
        IERC20(token).safeTransferFrom(from, to, amount);
        emit ExchangedFrom(token, from, to, amount);
    }

    function _withdraw(address token, address to, uint amount) internal {
        IERC20(token).safeTransfer(to, amount);
        emit Withdraw(token, to, amount);
    }

    function _exchange(address token, address to, uint amount) internal {
        if (token == address(0)) {
            (bool callSuccess, ) = payable(to).call{value: amount}("");
            if (!callSuccess) {
                revert NotSuccessTransferNative(to, amount);
            }
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        emit Exchanged(token, to, amount);
    }

    function _calculateFee(
        address fromToken,
        address toToken,
        uint amount
    )
        internal
        view
        onlyAllowedTokens(fromToken, toToken)
        returns (uint fee, uint transferAmount)
    {
        uint256 rate;

        Rate memory fromRate = fromToken == address(0)
            ? _nativeRate
            : _tokenWhiteList[IERC20(fromToken)];
        Rate memory toRate = toToken == address(0)
            ? _nativeRate
            : _tokenWhiteList[IERC20(toToken)];

        Fee memory feeStruct = fromRate.fee;

        int decimalDifference = int8(_getDecimals(toToken)) -
            int8(_getDecimals(fromToken));

        if (fromToken == address(_baseToken)) {
            rate = toRate.baseRate;
            transferAmount = amount.mul(10 ** _getDecimals(toToken)).div(rate);
            fee = 0;

            if (decimalDifference > 0) {
                transferAmount = transferAmount.mul(
                    10 ** uint(decimalDifference)
                );
            } else if (decimalDifference < 0) {
                transferAmount = transferAmount.div(
                    10 ** uint(-decimalDifference)
                );
            } else if (
                decimalDifference == 0 && fromToken != address(_baseToken)
            ) {
                transferAmount = transferAmount.div(
                    10 ** uint(_getDecimals(toToken))
                );
            }
        } else {
            rate = fromRate.baseRate;
            fee = amount.mul(feeStruct.numerator).div(feeStruct.denominator);
            uint256 netAmount = amount.sub(fee);
            transferAmount = netAmount.mul(rate).div(
                10 ** _getDecimals(fromToken)
            );
        }

        if (_getLiquidity(toToken) < transferAmount) {
            revert NotEnoughLiquidity(toToken, amount);
        }
    }

    function _beforeExchange(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount
    ) internal virtual {}

    function _afterExchange(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount
    ) internal virtual {}
}
