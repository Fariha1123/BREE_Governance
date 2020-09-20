# BREE_Governance

The bree governance contract is compliant to following requirements:

## Governance Contract
- Creating Proposals
- Voting
- Trust Scores

Fees for creating proposal: $100 in BREE
Fees for 1 vote: $1 in BREE

Votes paid in BREE are allocated as follows for each proposal:
5% goes to the proposal creator (only if proposal ends as ACCEPTED)
10% is allocated to all voters who have voted on the winning vote (proportionate to the amounts of BREE they have used to vote)
85% is allocated for burning (+5% if proposal ends as rejected)

Trust scores are gained/deducted by the contract only. Users cannot transfer these. All trust scores gained expire after 14 days.

How a winning vote is determined on proposals:
Upon the default voting period of 7 days ending, the proposal may be ended as ACCEPTED or REJECTED. For a winning vote to be determined, it should meet ALL of the requirements below:
1. Combined vote counts on the winning vote must be higher than the opposing vote
2. Combined trust scores of users (at time of proposal ending) must be higher or equal to the opposing vote


Proposals are created on-chain with set subjects (category). User selects category & inputs text message data on-chain.

Full list of categories:
- Staking Rates
- Farming Rates
- Add/Delete Governance Asset
- Staker Whitelisting
- Staking Period
- Staking Rewards Collection Fees
- Yield Collection Fees
- Proposal Creation Fees
- Voting Fees
- Votes Distribution
- Trust Scores
- Others

1. When creating proposals, users are required to pay $100 in BREE (needs oracle to fetch price of BREE in USD). 
2. Fees paid as such are sent directly to the burn address (0x000)
3. Each proposal runs for a period of 7 days. If no resoultion is met in 7 days, it is resubmitted for another 7 days. This continues until a resolution is met (votes continue to pile up regardless of it being re-opened for voting).
4. Proposals should show status = Accepted, Rejected, On-going
5. Proposals should be arranged in the form of numbered ID (e.g. 1, 2, 3)
6. If proposal ends as 'Accepted', the proposal creator gets 5% of all votes paid in BREE on that particular proposal. If rejected, this is allocated for burning.

Query Functions
1. Proposal status (input proposal ID & returns status Accepted or Rejected or On-going)
2. Proposal vote counts (input proposal ID and it shows how many BREE was voted for YES and NO)
3. Proposal combined trust scores (input proposal ID and it shows the combined trust scores of users who voted YES and the combined trust scores of users who voted NO, separately - this must update every second because trust scores gained by individual users expire after 14 days of gaining it, combined trust scores may be different on a second to second basis)
4. Proposal period (only for on-going proposals, input proposal ID and it shows the time left until proposal voting period ends)


Voting - users can vote YES or NO on proposals.
1. Minimum they can spend on a vote is $1 in BREE. There is no maximum.
2. Each proposal has its own vote counts.
3. Winning voters will share 10% of the total votes (proportionately allocated to the amounts of BREE they have used to vote on the winning vote).
e.g. John votes YES on proposal #1 with 100 BREE. Proposal #1 ends as Accepted. Total combined number of votes paid on YES by users = 2000 BREE. Users will proportionately share 10% of 2000 BREE which is 200 BREE. John's allocation is 5% of 200 BREE. John has been allocated 10 BREE on proposal #1. John may claim his 10 BREE at any time he wishes to do so by interacting with the contract's 'CLAIM EARNINGS' function.
4. 85% of all votes paid (YES & NO) are burned when the proposal ends (with a resolution met). 

Query Functions
1. Votes paid by an address on proposal (user inputs proposal # and his address. It shows how much the user has paid on which vote - yes or no).
2. Claimable Earnings (user inputs proposal # and his address. It shows how much the user has earned & is currently claimable.
3. Total Claimed Earnings (shows how much has been claimed by a user until today)
4. Total Claimed Earnings of ALL users until today

Trust scores: can be gained/deducted based on past performance of voting on proposals. Lowest a trust score can go is 0 it should not have negative value.
NOTE: When voting, trust scores are NOT used. Combined trust scores (balance) of users are simply queried when the proposal ends.

+1 for voting on a winning vote on a proposal
+1 for creating a proposal which has ended as 'Accepted'
-1 for voting on a losing vote on a proposal
-1 for creating a proposal which has ended as 'Rejected'

**Trust scores will only be from last 5 proposals. Meaning, if user voted on proposal #1 and his trust score was 0, later when he come to vote on proposal #10, then his
trust score will be from last proposal number to last 5 i.e. proposal #9 to proposal #5 

Query Functions
1. My trust score balance (input user address and shows current trust score of the address)
2. Latest trust score (from only 5 latest proposals)
3. Trust score gained/deducted by proposal # (input proposal ID & user address - shows trust score gained or deducted on tht particular proposal)
4. Total combined trust scores of all users (global) which is active/not expired.

Owner Functions
1. Ability to edit fees for creating proposals (USD value of BREE) (default: $100)
2. Ability to change % allocated/distributed to proposal creator upon proposals ending as accepted (default: 5%)
3. Ability to change % allocated/distributed to winning voters (default: 10%)
4. Ability to change % allocated/distributed for burning (default: 85%)
** 2,3,4 needs to combine as 100%. 
5. Ability to add/delete fixed category when creating new proposals (string data)
6. Ability to edit default voting period for proposals (default: 7 days)
7. Ability to edit MINIMUM fees for votes (USD value of BREE) (default: $1)
8. Ability to edit the amounts +/- for trust scores (according to the 4 fixed criteria explained above - so it would be easier to arrange them in simple IDs like 1,2,3,4 so that when I edit, I just have to input ID 1 (for voting on a winning vote on a proposal), change to value 2 (for +2) or value -2 (for -2).
9. Ability to edit trust score expiration period (default: latest 5 overall proposals)
