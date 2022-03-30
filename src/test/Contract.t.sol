// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/users/ERC721User.sol";
import {YieldToken} from "../Contract.sol";

contract StakingTest is DSTest {
    Vm public vm = Vm(HEVM_ADDRESS);
    MockERC721 internal nft;
    YieldToken public staker;
    ERC721User public alice;

    function setUp() public {
        nft = new MockERC721("MockNFT", "Mock");
        staker = new YieldToken("Staker", "Staker", address(nft));
    
        alice = new ERC721User(nft);
        vm.label(address(alice), "Alice");

        nft.mint(address(alice), 1);
        nft.mint(address(alice), 2);
        assertEq(nft.ownerOf(1), address(alice));
    }

    function testClaim() public {
        vm.warp(0);
        vm.startPrank(address(alice));
        
        nft.approve(address(staker), 1);
        staker.deposit(1);

        vm.warp(1 days);
        staker.claim();
        assertEq(staker.balanceOf(address(alice)), 1 ether);
    }

    function testClaimMulitplier() public {
        vm.warp(0);
        vm.startPrank(address(alice));
        nft.approve(address(staker), 1);
        nft.approve(address(staker), 2);
        staker.deposit(1);
        staker.deposit(2);

        vm.warp(1 days);
        staker.claim();
        assertEq(staker.balanceOf(address(alice)), 2 ether);        
    }

    function testClaimWhenNoDeposit(address any) public {
        if (address(alice) == any) return;
        if (address(0) == any) return;
        vm.startPrank(any);
        vm.expectRevert("Nothing to claim");
        staker.claim();
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(address(alice));
        nft.approve(address(staker), 1);
        staker.deposit(1);
        vm.stopPrank();

        assertEq(staker.count(address(alice)), 1);
        assertEq(nft.ownerOf(1), address(staker));
    }

    function testDepositUnapprovedToken() public {
        vm.startPrank(address(alice));
        vm.expectRevert("Not approved");
        staker.deposit(1);
    }

    function testWitdraw() public {
        vm.startPrank(address(alice));
        nft.approve(address(staker), 1);
        staker.deposit(1);
        vm.warp(1 days);
        staker.withdraw(1);
        vm.stopPrank();
    }

    function testWithdrawWhenNoDeposit(address other) public {
        if (address(alice) == address(other)) return;
        vm.startPrank(address(alice));
        nft.approve(address(staker), 1);
        staker.deposit(1);
        vm.stopPrank();

        vm.warp(1 days);
        vm.prank(other);
        vm.expectRevert("Not staked");
        staker.withdraw(1);
    }
}
