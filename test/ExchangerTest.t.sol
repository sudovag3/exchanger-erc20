// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {Vault} from "../../src/Vault.sol";
import {MyToken} from "../../src/test/MyToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/test/MyNftToken.sol";
import {Exchanger, IExchanger} from "../../src/Exchanger.sol";
import {EQuicoin} from "../src/test/EQuicoin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ExchangerTest is Test {
    using SafeMath for uint;
    Vault vault;
    MyToken token;
    Exchanger exchanger;

    address public OWNER = makeAddr("owner");
    address public PLAYER = makeAddr("player");
    address public PLAYER1 = makeAddr("player1");

    address public USDT_OWNER = makeAddr("usdtowner");

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant TOKEN_AMOUNT = 1000 * 10 ** 18; // 1000 tokens
    uint256 public constant TRANSFER_AMOUNT = 10 * 10 ** 18; // 1000 tokens

    function setUp() external {
        vm.prank(OWNER);
        token = new MyToken();

        vm.prank(OWNER);
        exchanger = new Exchanger(address(token));
    }

    function testExchangeToBaseToken(
        uint128 _amount,
        uint8 decimals,
        uint8 numerator,
        uint8 denominator
    ) public {
        uint amount = uint(_amount);
        numerator = numerator % 100;
        denominator = (denominator % 100) + 1 + numerator;
        amount += 1;
        decimals = (decimals % 10) + 1;
        vm.prank(OWNER);
        EQuicoin testUSDTToken = new EQuicoin(
            amount * 10 ** decimals,
            "testUSDTToken",
            "TST",
            decimals
        );

        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(numerator, denominator),
            baseRate: 100 * 10 ** 18
        });

        vm.prank(OWNER);
        exchanger.setTokenRate(IERC20(address(testUSDTToken)), rate);

        uint fee = amount.mul(numerator).div(denominator);
        uint netAmount = amount.sub(fee);
        uint expectedTransferAmount = netAmount.mul(rate.baseRate).div(
            10 ** decimals
        );

        vm.prank(OWNER);
        token.mint(address(exchanger), expectedTransferAmount);
        vm.prank(OWNER);
        testUSDTToken.issue(amount);

        (uint calculatedFee, uint calculatedTransferAmount) = exchanger
            .calculateFee(address(testUSDTToken), address(token), amount);

        assert(calculatedFee == fee);
        assert(calculatedTransferAmount == expectedTransferAmount);

        vm.prank(OWNER);
        testUSDTToken.transfer(PLAYER, amount);

        vm.prank(PLAYER);
        testUSDTToken.approve(address(exchanger), amount);

        vm.prank(PLAYER);
        exchanger.exchange(address(testUSDTToken), address(token), amount);

        assert(testUSDTToken.balanceOf(PLAYER) == 0);
        assert(token.balanceOf(PLAYER) == expectedTransferAmount);
    }

    function testExchangeFromBaseToken(
        uint32 _amount,
        uint8 decimals,
        uint8 numerator,
        uint8 denominator
    ) public {
        uint amount = uint(_amount);
        numerator = numerator % 100;
        denominator = (denominator % 100) + 1 + numerator;
        decimals = (decimals % 10) + 1;
        amount += 1;
        amount *= 10 ** decimals;

        vm.prank(OWNER);
        EQuicoin testUSDTToken = new EQuicoin(
            amount * 10 ** decimals,
            "testUSDTToken",
            "TST",
            decimals
        );

        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(numerator, denominator),
            baseRate: 100 * 10 ** 18
        });

        vm.prank(OWNER);
        exchanger.setTokenRate(IERC20(address(testUSDTToken)), rate);

        uint expectedTransferAmount = amount.mul(10 ** decimals).div(
            rate.baseRate
        );
        if (decimals > 18) {
            expectedTransferAmount = expectedTransferAmount.mul(
                10 ** (decimals - 18)
            );
        } else if (decimals < 18) {
            expectedTransferAmount = expectedTransferAmount.div(
                10 ** (18 - decimals)
            );
        }

        vm.prank(OWNER);
        token.mint(PLAYER, amount);

        if (expectedTransferAmount != 0) {
            vm.prank(OWNER);
            testUSDTToken.issue(expectedTransferAmount);
            vm.prank(OWNER);
            testUSDTToken.transfer(address(exchanger), expectedTransferAmount);
        }

        (uint calculatedFee, uint calculatedTransferAmount) = exchanger
            .calculateFee(address(token), address(testUSDTToken), amount);

        assert(calculatedFee == 0);
        assert(calculatedTransferAmount == expectedTransferAmount);

        vm.prank(PLAYER);
        token.approve(address(exchanger), amount);

        vm.prank(PLAYER);
        exchanger.exchange(address(token), address(testUSDTToken), amount);

        assert(token.balanceOf(PLAYER) == 0);
        assert(testUSDTToken.balanceOf(PLAYER) == expectedTransferAmount);
    }

    function testNativeExchangeToBaseToken(
        uint32 _amount,
        uint8 numerator,
        uint8 denominator
    ) public {
        uint amount = uint(_amount);
        uint8 decimals = 18;
        numerator = numerator % 100;
        denominator = (denominator % 100) + 1 + numerator;
        amount += 1;
        amount *= 10 ** 18;

        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(numerator, denominator),
            baseRate: 100 * 10 ** decimals
        });

        vm.prank(OWNER);
        exchanger.setNativeRate(rate);

        uint fee = amount.mul(numerator).div(denominator);
        uint netAmount = amount.sub(fee);
        uint expectedTransferAmount = netAmount.mul(rate.baseRate);
        expectedTransferAmount = expectedTransferAmount.div(10 ** decimals);

        vm.prank(OWNER);
        token.mint(address(exchanger), expectedTransferAmount);

        (uint calculatedFee, uint calculatedTransferAmount) = exchanger
            .calculateFee(address(0), address(token), amount);

        assert(calculatedFee == fee);
        assert(calculatedTransferAmount == expectedTransferAmount);

        vm.deal(PLAYER, amount);

        vm.prank(PLAYER);
        (bool success, ) = payable(address(exchanger)).call{value: amount}("");
        assert(success == true);
        assert(token.balanceOf(PLAYER) == expectedTransferAmount);
    }

    function testNativeExchangeFromBaseToken(
        uint32 _amount,
        uint8 numerator,
        uint8 denominator
    ) public {
        uint amount = uint(_amount);
        uint8 decimals = 18;
        numerator = numerator % 100;
        denominator = (denominator % 100) + 1 + numerator;
        amount += 1;
        amount *= 10 ** decimals;

        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(numerator, denominator),
            baseRate: 100 * 10 ** decimals
        });

        vm.prank(OWNER);
        exchanger.setNativeRate(rate);

        uint expectedTransferAmount = amount.mul(10 ** decimals).div(
            rate.baseRate
        );

        vm.prank(OWNER);
        token.mint(PLAYER, amount);

        vm.deal(address(exchanger), expectedTransferAmount);

        (uint calculatedFee, uint calculatedTransferAmount) = exchanger
            .calculateFee(address(token), address(0), amount);

        assert(calculatedFee == 0);
        assert(calculatedTransferAmount == expectedTransferAmount);

        vm.prank(PLAYER);
        token.approve(address(exchanger), amount);

        vm.prank(PLAYER);
        exchanger.exchange(address(token), address(0), amount);

        assert(token.balanceOf(PLAYER) == 0);
    }

    function testGetRate(
        uint8 decimals,
        uint8 numerator,
        uint8 denominator
    ) public {
        decimals %= 18;
        if (denominator == 0) {
            denominator++;
        }
        vm.prank(OWNER);
        EQuicoin testUSDTToken = new EQuicoin(
            0,
            "testUSDTToken",
            "TST",
            decimals
        );

        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(numerator, denominator),
            baseRate: 100 * 10 ** 18
        });

        vm.prank(OWNER);
        exchanger.setTokenRate(IERC20(address(testUSDTToken)), rate);

        IExchanger.Rate memory fetchedRate = exchanger.getRate(
            address(testUSDTToken)
        );
        assert(fetchedRate.baseRate == rate.baseRate);
        assert(fetchedRate.fee.numerator == rate.fee.numerator);
        assert(fetchedRate.fee.denominator == rate.fee.denominator);
    }

    function testGetBaseToken() public view {
        IERC20 baseToken = exchanger.getBaseToken();
        assert(address(baseToken) == address(token));
    }

    function testGetVault() public view {
        Vault fetchedVault = exchanger.getVault();
        assert(address(fetchedVault) == address(exchanger.getVault()));
    }

    function testRemoveNativeRate() public {
        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(5, 100),
            baseRate: 100 * 10 ** 18
        });

        vm.prank(OWNER);
        exchanger.setNativeRate(rate);

        IExchanger.Rate memory fetchedRateBefore = exchanger.getNativeRate();
        assert(fetchedRateBefore.baseRate == rate.baseRate);

        vm.prank(OWNER);
        exchanger.removeNativeRate();

        IExchanger.Rate memory fetchedRateAfter = exchanger.getNativeRate();
        assert(fetchedRateAfter.baseRate == 0);
    }

    function testRemoveTokenRate() public {
        uint8 decimals = 18;
        uint8 numerator = 5;
        uint8 denominator = 100;
        vm.prank(OWNER);
        EQuicoin testUSDTToken = new EQuicoin(
            0,
            "testUSDTToken",
            "TST",
            decimals
        );

        IExchanger.Rate memory rate = IExchanger.Rate({
            fee: IExchanger.Fee(numerator, denominator),
            baseRate: 100 * 10 ** 18
        });

        vm.prank(OWNER);
        exchanger.setTokenRate(IERC20(address(testUSDTToken)), rate);

        IExchanger.Rate memory fetchedRateBefore = exchanger.getRate(
            address(testUSDTToken)
        );
        assert(fetchedRateBefore.baseRate == rate.baseRate);

        vm.prank(OWNER);
        exchanger.removeTokenRate(IERC20(address(testUSDTToken)));

        IExchanger.Rate memory fetchedRateAfter = exchanger.getRate(
            address(testUSDTToken)
        );
        assert(fetchedRateAfter.baseRate == 0);
    }
}
