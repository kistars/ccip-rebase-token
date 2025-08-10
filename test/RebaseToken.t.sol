// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner); // 开始模拟owner地址的身份
        // owner部署合约, 调用function
        rebaseToken = new RebaseToken();
        vault = new Vault(address(rebaseToken));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 amount) public {
        vm.deal(address(vault), amount + 100e18);
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, 1e20); // 使用更合理的范围，避免溢出
        vm.startPrank(user); // 开始模拟user地址的身份
        vm.deal(user, amount); // give the user some ETH
        vault.deposit{value: amount}();

        // initial balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);

        // time elapsed
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, amount);

        // time elapsed
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    function testRedeem(uint256 amount) public {
        amount = bound(amount, 1e5, 1e20); // 使用更合理的范围，避免溢出
        vm.startPrank(user); // 开始模拟user地址的身份
        vm.deal(user, amount); // give the user some ETH
        // deposit
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        // redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemWithInterest(uint256 amount) public {
        uint256 depositAmount = bound(amount, 1e5, 1e20); // 使用更合理的范围，避免溢出
        // deposit
        vm.deal(user, depositAmount); // give the user some ETH
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // calculate interest
        vm.warp(block.timestamp + 30 seconds);
        uint256 balance = rebaseToken.balanceOf(user);
        // check balance
        assertGt(balance, depositAmount);
        // add rewards to vault
        addRewardsToVault(balance - depositAmount);
        // redeem
        vm.prank(user);
        vault.redeem(balance);
        assertEq(address(user).balance, balance);
        assertEq(rebaseToken.balanceOf(user), 0);
    }
}
