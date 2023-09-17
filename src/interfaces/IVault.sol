// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault {
    error NotSuccessWithdraw(IERC20 token, address to, uint amount);
    error NotSuccessFund(IERC20 token, address from, uint amount);
    error NotSuccessWithdrawNative(address to, uint amount);

    event VaultWithdraw(
        IERC20 indexed token,
        address indexed to,
        uint indexed amount
    );

    event VaultWithdrawNative(address indexed to, uint indexed amount);

    event VaultFund(
        IERC20 indexed token,
        address indexed from,
        uint indexed amount,
        uint receiptId
    );

    event VaultFundNative(
        address indexed from,
        uint indexed amount,
        uint indexed receiptId
    );

    function fundNative(address from) external payable;

    function fund(IERC20 token, address from, uint amount) external;

    function withdraw(IERC20 token, uint amount) external;

    function withdrawNative(uint amount) external;
}
