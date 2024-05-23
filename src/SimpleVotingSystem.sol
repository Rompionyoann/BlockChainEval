// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract SimpleVotingSystem is AccessControl {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        address founder; // Address of the founder who added the candidate
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }
    WorkflowStatus public workflowStatus;
    uint256 public voteStartTime; // Timestamp when VOTE status is set

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;

    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Only an admin can perform this action"
        );
        _;
    }

    modifier onlyFounder() {
        require(
            hasRole(FOUNDER_ROLE, msg.sender),
            "Only a founder can perform this action"
        );
        _;
    }

    modifier inWorkflowStatus(WorkflowStatus status) {
        require(
            workflowStatus == status,
            "Function cannot be called at this time"
        );
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender); // Make deployer also a founder
        workflowStatus = WorkflowStatus.REGISTER_CANDIDATES;
    }

    function addAdmin(address account) public onlyAdmin {
        _grantRole(ADMIN_ROLE, account);
    }

    function removeAdmin(address account) public onlyAdmin {
        _revokeRole(ADMIN_ROLE, account);
    }

    function addFounder(address account) public onlyAdmin {
        _grantRole(FOUNDER_ROLE, account);
    }

    function removeFounder(address account) public onlyAdmin {
        _revokeRole(FOUNDER_ROLE, account);
    }

    function addCandidate(
        string memory _name
    ) public onlyFounder inWorkflowStatus(WorkflowStatus.REGISTER_CANDIDATES) {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0, msg.sender);
        candidateIds.push(candidateId);
    }

    function startVoting()
        public
        onlyAdmin
        inWorkflowStatus(WorkflowStatus.FOUND_CANDIDATES)
    {
        workflowStatus = WorkflowStatus.VOTE;
        voteStartTime = block.timestamp; // Set the start time for voting
    }

    function endVoting()
        public
        onlyAdmin
        inWorkflowStatus(WorkflowStatus.VOTE)
    {
        workflowStatus = WorkflowStatus.COMPLETED;
    }

    function vote(
        uint _candidateId
    ) public inWorkflowStatus(WorkflowStatus.VOTE) {
        require(
            block.timestamp >= voteStartTime + 1 hours,
            "Voting can only start 1 hour after the VOTE status is set"
        );
        require(!voters[msg.sender], "You have already voted");
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;
    }

    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    function getCandidate(
        uint _candidateId
    ) public view returns (Candidate memory) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId];
    }

    function setWorkflowStatus(WorkflowStatus _status) public onlyAdmin {
        workflowStatus = _status;
    }

    function getWinner()
        public
        view
        inWorkflowStatus(WorkflowStatus.COMPLETED)
        returns (Candidate memory)
    {
        uint maxVotes = 0;
        uint winnerId;
        for (uint i = 1; i <= candidateIds.length; i++) {
            if (candidates[i].voteCount > maxVotes) {
                maxVotes = candidates[i].voteCount;
                winnerId = i;
            }
        }
        return candidates[winnerId];
    }

    function sendFundsToCandidate(
        uint _candidateId
    )
        public
        payable
        inWorkflowStatus(WorkflowStatus.FOUND_CANDIDATES)
        onlyFounder
    {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        candidates[_candidateId].voteCount += msg.value;
    }
}
