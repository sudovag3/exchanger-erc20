// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVault, IERC20} from "./interfaces/IVault.sol";
import {MyNftToken} from "./test/MyNftToken.sol";

/// @title Vault Contract
/// @notice This contract allows for depositing and withdrawing of ERC20 tokens and native ether.
/// @dev Uses OpenZeppelin's Ownable for access control.
contract Vault is IVault, Ownable {
    MyNftToken private _collection;
    address private _root;

    constructor(address owner) Ownable() {
        _collection = new MyNftToken();
        _root = _msgSender();
        transferOwnership(owner);
    }

    function getCollection() external view returns (address) {
        return address(_collection);
    }

    /// @notice Allows a user to deposit a specified amount of ERC20 tokens into the vault.
    function fund(IERC20 token, address from, uint amount) external {
        _fund(token, from, amount);
    }

    /// @notice Allows a user to deposit native ether into the vault.
    function fundNative(address from) public payable {
        if (from != _root) {
            uint receiptId = _mintReceipt(from);
            emit VaultFundNative(from, msg.value, receiptId);
        }
    }

    /// @notice Allows the owner to withdraw a specified amount of ERC20 tokens from the vault.
    function withdraw(IERC20 token, uint amount) external onlyOwner {
        _beforeTokenTransfer(token, owner(), amount);
        _withdraw(token, amount);
        _afterTokenTransfer(token, owner(), amount);
    }

    /// @notice Allows the owner to withdraw a specified amount of native ether from the vault.
    function withdrawNative(uint amount) external onlyOwner {
        _withdrawNative(amount);
    }

    function _withdraw(IERC20 token, uint amount) internal {
        SafeERC20.safeTransfer(token, owner(), amount);

        emit VaultWithdraw(token, owner(), amount);
    }

    function _withdrawNative(uint amount) internal {
        (bool callSuccess, ) = payable(owner()).call{value: amount}("");
        if (!callSuccess) {
            revert NotSuccessWithdrawNative(owner(), amount);
        }
        emit VaultWithdrawNative(owner(), amount);
    }

    function _fund(IERC20 token, address from, uint amount) internal {
        SafeERC20.safeTransferFrom(token, from, address(this), amount);

        uint receiptId = _mintReceipt(from);

        emit VaultFund(token, from, amount, receiptId);
    }

    function _mintReceipt(address to) internal returns (uint) {
        uint receiptId = _collection.getCurrentTokenIdCounter();

        _collection.safeMint(to);

        return receiptId;
    }

    /// @dev Hook that is called before any token transfer. This can be overridden for custom logic.
    function _beforeTokenTransfer(
        IERC20 token,
        address to,
        uint amount
    ) internal virtual {}

    /// @dev Hook that is called after any token transfer. This can be overridden for custom logic.
    function _afterTokenTransfer(
        IERC20 token,
        address to,
        uint amount
    ) internal virtual {}

    fallback() external payable {
        fundNative(_msgSender());
    }

    receive() external payable {
        fundNative(_msgSender());
    }
}
