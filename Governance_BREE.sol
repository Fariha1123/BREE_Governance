// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
  
  function ceil(uint a, uint m) internal pure returns (uint r) {
    return (a + m - 1) / m * m;
  }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// ----------------------------------------------------------------------------
interface IBREE {
    function transfer(address to, uint256 tokens) external returns (bool success);
    function transferFrom(address from, address to, uint256 tokens) external returns (bool success);
    function BurnTokens(uint256 _amount) external;
}

contract Governance{
    
    using SafeMath for uint256;
    
    uint256 proposalCreationFeeUSD = 100; // usd
    uint256 votingFeeUSD = 1; // usd
    uint256 XETHUSDRate = 350; // usd
    
    uint256 public totalProposals;
    uint256 public proposalPeriod = 7 days;
    uint256 public totalEarningsClaimed;
    
    address BREE = 0x8c1eD7e19abAa9f23c476dA86Dc1577F1Ef401f5;
    
    string[] categories;
    mapping(uint256 => Proposal) public proposals;
    
    enum Status {_, ACCEPTED, REJECTED, ACTIVE}
    
    struct Proposal{
        uint256 id;
        string  description;
        uint256 categoryId;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes; 
        address creator;
        uint256 yesTrustScores;
        uint256 noTrustScores;
        uint256 creatorPortion;
        uint256 yesVotersPortion;
        Status  status;
    }
    
    struct proposalsVotes{
        bool voted;
        bool choice; // true = yes, false = no
        uint256 breePaid;
        bool rewardsClaimed;
        uint256 totalClaimed;
    }
    
    struct Voters{
        mapping(uint256 => proposalsVotes) proposalsVoted;
        uint256 latestTrustScore;
        mapping(uint256 => uint256 ) allProposalsVoted;
        uint256 totalClaimed;
    }
    
    mapping(address => Voters) voters;
    
    constructor() public {
        // set the mapping
        categories.push("StakingRates");
        categories.push("FarmingRates");
        categories.push("AddDeleteGovernanceAsset");
        categories.push("StakerWhitelisting");
        categories.push("StakingPeriod");
        categories.push("StakingRewardsCollectionFees");
        categories.push("YieldCollectionFees");
        categories.push("ProposalCreationFees");
        categories.push("VotingFees");
        categories.push("VotesDistribution");
        categories.push("TrustScores");
        categories.push("Others");
    }
    
    modifier validCategory(uint256 categoryId){
        require(categoryId >= 0 && categoryId <= categories.length, "CATEGORY ID: Invalid Category Id");
        _;
    }
    
    modifier descriptionNotNull(string memory ideaDescription){
        bytes memory ideaDescriptionBytes = bytes(ideaDescription); // Uses memory
        require(ideaDescriptionBytes.length != 0, "Description NULL: Proposal description should not be null");
        _;
    }
    
    modifier notVoted(uint256 proposalId){
        require(!voters[msg.sender].proposalsVoted[proposalId].voted);
        _;
    }
    
    // Create proposal by paying fee in BREE
    function CREATE_PROPOSAL(uint256 categoryId, string calldata ideaDescription) external validCategory(categoryId) descriptionNotNull(ideaDescription){
        // get the fee from user
        require(IBREE(BREE).transferFrom(msg.sender, address(this), _calculateProposalFee()));
        
        // burn the received tokens
        IBREE(BREE).BurnTokens(_calculateProposalFee());
        
        // REGISTER THE PROPOSAL
        
        // increment the proposals count
        totalProposals = totalProposals.add(1);
        
        // add the proposal to mapping
        proposals[totalProposals] = Proposal({
           id: totalProposals,
           description: ideaDescription,
           categoryId: categoryId,
           endTime: block.timestamp.add(proposalPeriod),
           status: Status.ACTIVE,
           creator: msg.sender,
           yesVotes: 0,
           noVotes: 0,
           yesTrustScores: 0,
           noTrustScores: 0,
           creatorPortion: 0,
           yesVotersPortion: 0
        });
    }
    
    // TO DO LOGIC
    function _calculateProposalFee() private pure returns(uint256 _fee){
        return 2; // in bree
    }
    
    // check if proposal is active
    function _updatedProposalStatus(uint256 proposalId) private returns(bool){
        // check if it is NOT in valid time frame
        if(block.timestamp > proposals[proposalId].endTime && proposals[proposalId].status == Status.ACTIVE){
            // check if yesVotes is greater than noVotes AND yesTrustScores is greater/equal to noTrustScores
            if(proposals[proposalId].yesVotes > proposals[proposalId].noVotes && proposals[proposalId].yesTrustScores >= proposals[proposalId].noTrustScores)
                proposals[proposalId].status = Status.ACCEPTED;
            // check if noVotes is greater than yesVotes AND noTrustScores is greater than yesTrustScores
            else if(proposals[proposalId].noVotes > proposals[proposalId].yesVotes && proposals[proposalId].noTrustScores > proposals[proposalId].yesTrustScores)
                proposals[proposalId].status = Status.REJECTED;
            else // no resolution is met
            {
                proposals[proposalId].status = Status.ACTIVE;
                proposals[proposalId].endTime = proposals[proposalId].endTime.add(proposalPeriod);
            }
        }
        return true;
    }
    
    function updateTrustScore(address user) private returns(bool){
        
        voters[user].latestTrustScore = 0;
        
        for(uint256 i = totalProposals; i>= totalProposals.sub(5); i--){    
            uint256 proposalId = proposals[i].id;
            if(proposals[proposalId].status == Status.ACCEPTED){
                if(voters[user].proposalsVoted[proposalId].choice == true){ // yes
                    // +1
                    voters[user].latestTrustScore = voters[user].latestTrustScore.add(1);
                }
                else{
                    // -1
                    voters[user].latestTrustScore = voters[user].latestTrustScore.sub(1);
                }
            }
            else if(proposals[proposalId].status == Status.REJECTED){
                if(voters[user].proposalsVoted[proposalId].choice == false){ // no
                    // +1
                    voters[user].latestTrustScore = voters[user].latestTrustScore.add(1);
                }
                else{
                    // -1
                    voters[user].latestTrustScore = voters[user].latestTrustScore.sub(1);
                }
            }
        }
        
        return true;
    }
    
    // Vote for a proposal by paying fee in BREE
    function VOTE(uint256 proposalId, bool voteChoice, uint256 votesPaidInBree) public notVoted(proposalId){
        uint256 fee = _calculateVotingFee();
        
        // require that the votesPaid should be greater than min fee allowed
        require(votesPaidInBree >= fee);
        
        // get the fee from user
        require(IBREE(BREE).transferFrom(msg.sender, address(this), votesPaidInBree));
        
        // update the proposal status
        _updatedProposalStatus(proposalId);
        
        // require the status of the proposal with provided id is active
        require(proposals[proposalId].status == Status.ACTIVE, "INACTIVE: Proposal is not active");
        
        // check the vote choice and update the yesVotes OR noVotes AND yesTrustScores or noTrustScores
        _castVote(proposalId, voteChoice, votesPaidInBree);
        
        // distribute the fee
            // burn 85% immediately
            IBREE(BREE).BurnTokens(onePercent(votesPaidInBree).mul(85));
            // keep 5% for contract creator
            proposals[proposalId].creatorPortion = proposals[proposalId].creatorPortion.add(onePercent(votesPaidInBree).mul(5));
            // keep 10% for yes voters
            proposals[proposalId].yesVotersPortion = proposals[proposalId].yesVotersPortion.add(onePercent(votesPaidInBree).mul(10));
    }
    
    // TO DO LOGIC
    function _calculateVotingFee() private pure returns(uint256 _fee){
        return 1; // in bree
    }
    
    // check the vote choice and update the yesVotes OR noVotes AND yesTrustScores or noTrustScores
    function _castVote(uint256 proposalId, bool voteChoice, uint256 feePaid) private{
        if(voteChoice){ // true i.e. YES
            // keep record of tokens paid for yes votes
            proposals[proposalId].yesVotes = proposals[proposalId].yesVotes.add(feePaid);
            // add the trust score of the user to yesTrustScores
            proposals[proposalId].yesTrustScores = (proposals[proposalId].yesTrustScores).add(voters[msg.sender].latestTrustScore);
            
        } else{
            // keep record of tokens paid for no votes
            proposals[proposalId].noVotes = proposals[proposalId].noVotes.add(feePaid);
            // add the trust score of the user to noTrustScores
            proposals[proposalId].noTrustScores = (proposals[proposalId].noTrustScores).add(voters[msg.sender].latestTrustScore);
        }
        
        voters[msg.sender].proposalsVoted[proposalId].voted = true;
        voters[msg.sender].proposalsVoted[proposalId].choice = voteChoice;
        voters[msg.sender].proposalsVoted[proposalId].breePaid = feePaid;
        
    }

    function claimEarnings(uint256 proposalId) external{
        // update the proposal status
        _updatedProposalStatus(proposalId);
        
        uint256 pendingEarnings = claimableEarnings(proposalId, msg.sender);
        
        // send token portion
        IBREE(BREE).transfer(msg.sender, pendingEarnings);
        
        // update that the user has claimed the rewards
        voters[msg.sender].proposalsVoted[proposalId].rewardsClaimed = true;
        
        voters[msg.sender].totalClaimed = voters[msg.sender].totalClaimed.add(pendingEarnings);
        voters[msg.sender].proposalsVoted[proposalId].totalClaimed = voters[msg.sender].proposalsVoted[proposalId].totalClaimed.add(pendingEarnings);
        totalEarningsClaimed = totalEarningsClaimed.add(pendingEarnings);
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////// PROPOSAL QUERY FUNCTIONS ////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function proposalStatus(uint256 proposalId) public view returns(string memory _status){
        if(proposals[proposalId].status == Status.ACCEPTED)
            return "Accepted";
        else if(proposals[proposalId].status == Status.REJECTED)
            return "Rejected";          
        else if(proposals[proposalId].status == Status.ACTIVE)
            return "Active";
        else return "Invalid proposal Id";
    }
    
    function proposalVoteCounts(uint256 proposalId) public view returns(uint256 _yesVotes, uint256 _noVotes){
        return(proposals[proposalId].yesVotes, proposals[proposalId].noVotes);
    }
    
    function proposalTrustScoreCounts(uint256 proposalId) public view returns(uint256 _yesTrustScore, uint256 _noTrustScore){
        return(proposals[proposalId].yesTrustScores, proposals[proposalId].noTrustScores);
    }
    
    function proposalTimeLeft(uint256 proposalId) public view returns(uint256 _timeLeft){
        if(proposals[proposalId].status == Status.ACTIVE){
            // check if it is NOT in valid time frame
            if(block.timestamp > proposals[proposalId].endTime){
                // check if yesVotes is greater than noVotes AND yesTrustScores is greater/equal to noTrustScores
                if(proposals[proposalId].yesVotes > proposals[proposalId].noVotes && proposals[proposalId].yesTrustScores >= proposals[proposalId].noTrustScores)
                    return 0;
                // check if noVotes is greater than yesVotes AND noTrustScores is greater than yesTrustScores
                else if(proposals[proposalId].noVotes > proposals[proposalId].yesVotes && proposals[proposalId].noTrustScores > proposals[proposalId].yesTrustScores)
                    return 0;
                else{ // no resolution is met
                    return (proposals[proposalId].endTime.add(proposalPeriod)).sub(proposals[proposalId].endTime);
                }
            } 
            else{
                if(proposals[proposalId].endTime > block.timestamp)
                    return proposals[proposalId].endTime.sub(block.timestamp);
                else return 0;
            }
        }
        else return 0;
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////// VOTES QUERY FUNCTIONS ////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    function votesPaid(uint256 proposalId, address user) external view returns(string memory _choice, uint256 _votesPaid){
        if(voters[user].proposalsVoted[proposalId].choice)
            _choice = "yes";
        else
            _choice = "no";
        return (_choice, voters[user].proposalsVoted[proposalId].breePaid);
    }
    
    function claimableEarnings(uint256 proposalId, address user) public view returns(uint256 _claimableEarnings){
        if(proposals[proposalId].status != Status.ACTIVE){

            uint256 tokenPortion = 0;
            uint256 userPortion = 0;
        
            if(proposals[proposalId].status == Status.ACCEPTED){
          
                require(!voters[msg.sender].proposalsVoted[proposalId].rewardsClaimed, "Already claimed");
          
                if(voters[msg.sender].proposalsVoted[proposalId].choice == true){
            // check the total bree's paid for yes
            tokenPortion = proposals[proposalId].yesVotersPortion.div(proposals[proposalId].yesVotes);
            userPortion = voters[msg.sender].proposalsVoted[proposalId].breePaid.mul(tokenPortion);
          } 
            
                if(proposals[proposalId].creator == user){
                    userPortion = userPortion.add(proposals[proposalId].creatorPortion);
                }
          
                return userPortion;
            } 
            else if(proposals[proposalId].status == Status.REJECTED && voters[msg.sender].proposalsVoted[proposalId].choice == false){
                require(!voters[msg.sender].proposalsVoted[proposalId].rewardsClaimed, "Already claimed");
            
                // check the total bree's paid for yes
                tokenPortion = proposals[proposalId].yesVotersPortion.div(proposals[proposalId].noVotes);
                userPortion = voters[msg.sender].proposalsVoted[proposalId].breePaid.mul(tokenPortion);
            }
        }
    }
    
    function userTotalClaimedEarnings(address user) external view returns(uint256){
        return voters[user].totalClaimed; 
    }
    
    function userClaimedEarnings(uint256 proposalId, address user) external view returns(uint256){
        return voters[user].proposalsVoted[proposalId].totalClaimed; 
    }
    
    function totalClaimedEarningsOfAllUsers() external view returns (uint256) {
        return totalEarningsClaimed;
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////// TRUST SCORES QUERY FUNCTIONS ////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    function myTrustScoreBalance(address user) external view returns(uint256){
        uint256 totalTrustScore = 0;
        for(uint256 i = totalProposals; i>= totalProposals.sub(5); i--){    
            uint256 proposalId = proposals[i].id; 
            if(proposals[proposalId].status == Status.ACCEPTED){
                if(voters[user].proposalsVoted[proposalId].choice == true){ // yes
                    // +1
                    totalTrustScore = totalTrustScore.add(1);
                }
                else{
                    // -1
                    totalTrustScore = totalTrustScore.sub(1);
                }
            }
            else if(proposals[proposalId].status == Status.REJECTED){
                if(voters[user].proposalsVoted[proposalId].choice == false){ // no
                    // +1
                    totalTrustScore = totalTrustScore.add(1);
                }
                else{
                    // -1
                    totalTrustScore = totalTrustScore.sub(1);
                }
            }
        }
        return totalTrustScore;
    }
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////// OWNER FUNCTIONS ////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    function changeProposalCreationFee(uint256 usdValue) external {
        proposalCreationFeeUSD = usdValue;
    }
    
    function changeProposalCreatorAllocations(uint256 newAllocation) external{
        // require
    }
    
    function changeWinningVotersAllocations(uint256 newAllocation) external{
        // require 
    }
    
    function changeBurningAllocations(uint256 newAllocation) external{
        // require
    }
    
    function changeVotingPeriod(uint256 newVotingPeriod) external{
        proposalPeriod = newVotingPeriod;
    }
    
    function changeMinimumFeeOfVotes(uint256 newAllowedMinimumFee) external{
        votingFeeUSD = newAllowedMinimumFee;
    }
    
    // ------------------------------------------------------------------------
    // Calculates onePercent of the uint256 amount sent
    // ------------------------------------------------------------------------
    function onePercent(uint256 _tokens) internal pure returns (uint256){
        uint256 roundValue = _tokens.ceil(100);
        uint onePercentofTokens = roundValue.mul(100).div(100 * 10**uint(2));
        return onePercentofTokens;
    }
}