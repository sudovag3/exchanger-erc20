// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {Vault} from "../../src/Vault.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/test/MyNftToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    event VaultFund(
        IERC20 indexed token,
        address indexed from,
        uint indexed amount,
        uint receiptId
    );

    Vault vault;
    MyToken token;
    MyNftToken collection;

    address public OWNER = makeAddr("owner");
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant TOKEN_AMOUNT = 1000 * 10 ** 18; // 1000 tokens
    uint256 public constant TRANSFER_AMOUNT = 10 * 10 ** 18; // 1000 tokens

    function setUp() external {
        vm.prank(OWNER);
        vault = new Vault(OWNER);
        vm.prank(OWNER);
        token = new MyToken();

        vm.prank(OWNER);
        token.mint(PLAYER, TOKEN_AMOUNT);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    //Testing Fund

    function testFund() public {
        vm.prank(PLAYER);
        token.approve(address(vault), TRANSFER_AMOUNT);

        collection = MyNftToken(vault.getCollection());
        uint receiptId = collection.getCurrentTokenIdCounter();

        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(vault));
        emit VaultFund(token, PLAYER, TRANSFER_AMOUNT, receiptId);

        vault.fund(token, PLAYER, TRANSFER_AMOUNT);

        assert(token.balanceOf(address(vault)) == TRANSFER_AMOUNT);
        address ownerOfReceipt = collection.ownerOf(receiptId);
        assert(ownerOfReceipt == PLAYER);
    }

    function testFundNative() public {
        vm.prank(PLAYER);
        vault.fundNative{value: 1 ether}(PLAYER);
        assert(address(vault).balance == 1 ether);
    }

    function testWithdrawByOwner() public {
        vm.prank(PLAYER);
        token.transfer(address(vault), TRANSFER_AMOUNT);
        vm.prank(OWNER);
        vault.withdraw(token, TRANSFER_AMOUNT);
        assert(token.balanceOf(OWNER) == TRANSFER_AMOUNT);
    }

    function testWithdrawNativeByOwner() public {
        vm.prank(PLAYER);
        vault.fundNative{value: 1 ether}(PLAYER);
        vm.prank(OWNER);
        vault.withdrawNative(1 ether);
        assert(address(OWNER).balance == 1 ether);
    }

    function testReceiveFunction() public {
        vm.prank(PLAYER);
        (bool callSuccess, ) = payable(vault).call{value: 1 ether}("");
        assert(address(vault).balance == 1 ether && callSuccess);
    }
}
