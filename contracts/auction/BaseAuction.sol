// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import '../PyroAuction.sol';
import '../interface/IAuction.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';

abstract contract BaseAuction is IAuction, ERC721Holder {
  using Address for address;
  event Canceled();

  event HighestBidIncreased(uint256 tokenId, address bidder, uint256 amount);

  event AuctionEnded(uint256 tokenId, address winner, uint256 amount);

  event AuctionCreated(
    uint256 tokenId,
    uint256 minimumBid,
    uint256 biddingTime,
    address payable beneficiaryAddress
  );

  // Errors that describe failures.

  // The triple-slash comments are so-called natspec
  // comments. They will be shown when the user
  // is asked to confirm a transaction or
  // when an error is displayed.

  /// The auction has already ended.
  error AuctionAlreadyEnded();
  /// There is already a higher or equal bid.
  error BidNotHighEnough(uint256 highestBid);
  /// The bid is below the minimum set at creation.
  error BidBelowMinimum();
  /// The auction has not ended yet.
  error AuctionNotYetEnded();
  /// The function auctionEnd has already been called.
  error AuctionEndAlreadyCalled();
  /// The function is not cancelable.
  error AuctionNotCancelable();

  PyroAuction public core;

  mapping(uint256 => Auction) public auctions;

  mapping(address => uint256) public pendingReturns;

  function createAuction(
    uint256 tokenId,
    uint256 minimumBid,
    uint256 biddingTime,
    address payable beneficiaryAddress
  ) external virtual override returns (bool success) {
    address owner = core.ownerOf(tokenId);
    require(owner == msg.sender || core.isApprovedForAll(owner, msg.sender));

    core.safeTransferFrom(owner, address(this), tokenId);

    if (auctions[tokenId].startTime != 0) revert('Token already on auction');
    Auction memory auction = Auction({
      tokenId: tokenId,
      winningBid: 0,
      minimumBid: minimumBid,
      biddingTime: biddingTime,
      startTime: block.timestamp,
      winningBidder: address(0x0),
      beneficiaryAddress: beneficiaryAddress,
      ended: false
    });
    auctions[tokenId] = auction;
    emit AuctionCreated(tokenId, minimumBid, biddingTime, beneficiaryAddress);
    return true;
  }

  /// Withdraw a bid that was overbid.
  function withdraw() external override returns (bool success) {
    uint256 amount = pendingReturns[msg.sender];
    if (amount > 0) {
      // It is important to set this to zero because the recipient
      // can call this function again as part of the receiving call
      // before `send` returns.
      pendingReturns[msg.sender] = 0;

      if (!payable(msg.sender).send(amount)) {
        // No need to call throw here, just reset the amount owing
        pendingReturns[msg.sender] = amount;
        return false;
      }
    }
    return true;
  }

  /// Cancel the auction only if it has not recieved any bids
  function cancelAuction(uint256 tokenId)
    external
    override
    returns (bool success)
  {
    Auction storage auction = auctions[tokenId];

    if (auction.startTime == 0) revert('Auction does not exist');
    if (auction.beneficiaryAddress != msg.sender) revert('Not beneficiary');
    if (auction.winningBid != 0 || auction.winningBidder != address(0x0)) {
      revert AuctionNotCancelable();
    }

    if (
      block.timestamp > auction.startTime + auction.biddingTime || auction.ended
    ) revert AuctionAlreadyEnded();

    auction.ended = true;
    emit Canceled();
    return true;
  }

  /// End the auction and send the highest bid
  /// to the beneficiary.
  function auctionEnd(uint256 tokenId) external override {
    // It is a good guideline to structure functions that interact
    // with other contracts (i.e. they call functions or send Ether)
    // into three phases:
    // 1. checking conditions
    // 2. performing actions (potentially changing conditions)
    // 3. interacting with other contracts
    // If these phases are mixed up, the other contract could call
    // back into the current contract and modify the state or cause
    // effects (ether payout) to be performed multiple times.
    // If functions called internally include interaction with external
    // contracts, they also have to be considered interaction with
    // external contracts.

    Auction storage auction = auctions[tokenId];

    // 1. Conditions
    if (auction.startTime == 0) revert('Auction does not exist');
    if (block.timestamp < auction.startTime + auction.biddingTime)
      revert AuctionNotYetEnded();
    if (auction.ended) revert AuctionEndAlreadyCalled();

    // 2. Effects
    auction.ended = true;
    emit AuctionEnded(tokenId, auction.winningBidder, auction.winningBid);

    // 3. Interaction
    auction.beneficiaryAddress.transfer(auction.winningBid);
  }

  function getAuction(uint256 _tokenId)
    external
    view
    override
    returns (
      uint256 tokenId,
      uint256 winningBid,
      uint256 minimumBid,
      uint256 biddingTime,
      uint256 startTime,
      address winningBidder,
      address payable beneficiaryAddress,
      bool ended
    )
  {
    Auction storage auction = auctions[_tokenId];
    return (
      auction.tokenId,
      auction.winningBid,
      auction.minimumBid,
      auction.biddingTime,
      auction.startTime,
      auction.winningBidder,
      auction.beneficiaryAddress,
      auction.ended
    );
  }
}
