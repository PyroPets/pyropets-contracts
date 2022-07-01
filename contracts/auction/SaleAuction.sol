// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import '../PyroAuction.sol';
import './BaseAuction.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract SaleAuction is BaseAuction {
  using Address for address;

  constructor(address _core) {
    require(_core != address(0x0));
    core = PyroAuction(_core);
  }

  function bid(uint256 tokenId) external payable {
    Auction storage auction = auctions[tokenId];

    // Revert the call if the bidding
    // period is over.
    if (
      block.timestamp > auction.startTime + auction.biddingTime || auction.ended
    ) revert AuctionAlreadyEnded();

    // If the bid is not higher, send the
    // money back (the revert statement
    // will revert all changes in this
    // function execution including
    // it having received the money).
    if (msg.value < auction.minimumBid || msg.value <= auction.winningBid)
      revert BidNotHighEnough(auction.winningBid);

    if (auction.winningBid != 0) {
      // Sending back the money by simply using
      // highestBidder.send(highestBid) is a security risk
      // because it could execute an untrusted contract.
      // It is always safer to let the recipients
      // withdraw their money themselves.
      pendingReturns[auction.winningBidder] += auction.winningBid;
    }
    auction.winningBidder = msg.sender;
    auction.winningBid = msg.value;
    emit HighestBidIncreased(tokenId, msg.sender, msg.value);
  }

  /// Claim the asset being auctioned
  function claim(uint256 tokenId) external override returns (bool success) {
    Auction storage auction = auctions[tokenId];
    if (auction.startTime == 0) revert('Auction does not exist');
    if (!auction.ended) revert AuctionNotYetEnded();
    if (msg.sender == auction.winningBidder) {
      core.safeTransferFrom(
        address(this),
        auction.winningBidder,
        auction.tokenId
      );
    } else if (auction.winningBidder == address(0x0)) {
      core.safeTransferFrom(
        address(this),
        auction.beneficiaryAddress,
        auction.tokenId
      );
    } else {
      revert('Not the winning bidder or the creator');
    }
    delete auctions[tokenId];
    return true;
  }
}
