// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleVotingSystem.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem public simpleVotingSystem;
    address public owner = address(this);
    address public admin = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);
    address public voter3 = address(4);
    address public founder = address(5);

    function setUp() public {
        simpleVotingSystem = new SimpleVotingSystem();
        simpleVotingSystem.grantRole(simpleVotingSystem.ADMIN_ROLE(), admin);
        simpleVotingSystem.grantRole(simpleVotingSystem.FOUNDER_ROLE(), admin);
        simpleVotingSystem.grantRole(
            simpleVotingSystem.FOUNDER_ROLE(),
            founder
        );
    }

    function testAddCandidate() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Bruno");
        SimpleVotingSystem.Candidate memory candidate = simpleVotingSystem
            .getCandidate(1);
        assertEq(candidate.name, "Bruno");
        assertEq(candidate.voteCount, 0);
        vm.stopPrank();
    }

    function testVoteWorkflowStatusNotVote() public {
        // Trying to vote when the workflow status is not VOTE
        vm.startPrank(voter1);
        vm.expectRevert("Function cannot be called at this time");
        simpleVotingSystem.vote(1);
        vm.stopPrank();
    }

    function testVoteWithinOneHour() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Bruno");
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        simpleVotingSystem.startVoting();
        vm.stopPrank();

        // Trying to vote within one hour after VOTE status is set
        vm.startPrank(voter1);
        vm.expectRevert(
            "Voting can only start 1 hour after the VOTE status is set"
        );
        simpleVotingSystem.vote(1);
        vm.stopPrank();
    }

    function testVoteAfterOneHour() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Bruno");
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        simpleVotingSystem.startVoting();
        vm.stopPrank();

        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours + 1);

        // Voting after one hour
        vm.startPrank(voter1);
        simpleVotingSystem.vote(1);
        SimpleVotingSystem.Candidate memory candidate = simpleVotingSystem
            .getCandidate(1);
        assertEq(candidate.voteCount, 1);
        vm.stopPrank();
    }

    function testVoteTwice() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Bruno");
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        simpleVotingSystem.startVoting();
        vm.stopPrank();

        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours + 1);

        // First vote
        vm.startPrank(voter1);
        simpleVotingSystem.vote(1);
        vm.stopPrank();

        // Attempt to vote a second time
        vm.startPrank(voter1);
        vm.expectRevert("You have already voted");
        simpleVotingSystem.vote(1);
        vm.stopPrank();
    }

    function testGetWinner() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Candidate 1");
        simpleVotingSystem.addCandidate("Candidate 2");
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        simpleVotingSystem.startVoting();
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours + 1);

        // Simulate votes
        vm.startPrank(voter1);
        simpleVotingSystem.vote(1);
        vm.stopPrank();
        vm.startPrank(voter2);
        simpleVotingSystem.vote(1);
        vm.stopPrank();
        vm.startPrank(voter3);
        simpleVotingSystem.vote(2);
        vm.stopPrank();

        vm.startPrank(admin);
        simpleVotingSystem.endVoting();
        SimpleVotingSystem.Candidate memory winner = simpleVotingSystem
            .getWinner();
        assertEq(winner.id, 1); // The winner should be Candidate 1
        vm.stopPrank();
    }

    function testSendFundsToCandidate() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Candidate 1");
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES
        );
        vm.stopPrank();

        // Send funds to the winner
        vm.deal(founder, 1 ether);
        vm.startPrank(founder);
        simpleVotingSystem.sendFundsToCandidate{value: 1 ether}(1); // Sending 1 ether
        SimpleVotingSystem.Candidate memory candidate = simpleVotingSystem
            .getCandidate(1);
        assertEq(candidate.voteCount, 1 ether);
        vm.stopPrank();
    }

    function testSendFundsToCandidateWhenStatusNotFound() public {
        vm.startPrank(admin);
        simpleVotingSystem.setWorkflowStatus(
            SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES
        );
        simpleVotingSystem.addCandidate("Candidate 1");
        vm.stopPrank();

        vm.deal(founder, 1 ether);
        vm.startPrank(founder);
        vm.expectRevert("Function cannot be called at this time");
        simpleVotingSystem.sendFundsToCandidate{value: 1 ether}(1); // Sending 1 ether
        vm.stopPrank();
    }
}
