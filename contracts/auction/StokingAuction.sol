// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import '../Pyro.sol';
import '../PyroAuction.sol';
import './BaseAuction.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract StokingAuction is BaseAuction {
  using Address for address;

  /// Invalid stoking donor
  error InvalidStokingPair();

  mapping(uint256 => uint256) public donors;

  constructor(address _core) {
    require(_core != address(0x0));
    core = PyroAuction(_core);
  }

  function createAuction(
    uint256 tokenId,
    uint256 minimumBid,
    uint256 biddingTime,
    address payable beneficiaryAddress
  ) external override returns (bool success) {
    if (!core.canStoke(tokenId)) revert('Pyro cannot stoke');
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

  function stokingCost(uint256 tokenId, uint256 donor)
    public
    view
    returns (uint256 cost)
  {
    uint256 aGeneration = core.generationOfPyro(donor);

    uint256 bGeneration = core.generationOfPyro(tokenId);

    cost = aGeneration > bGeneration
      ? core.pyroGenesisCosts(aGeneration)
      : core.pyroGenesisCosts(bGeneration);
    return cost;
  }

  function bid(uint256 tokenId, uint256 donor) external payable {
    Auction storage auction = auctions[tokenId];

    // Revert the call if the bidding
    // period is over.
    if (
      block.timestamp > auction.startTime + auction.biddingTime || auction.ended
    ) revert AuctionAlreadyEnded();

    if (!core.isValidStokingPair(donor, tokenId)) revert InvalidStokingPair();

    uint256 amount = msg.value - stokingCost(donor, tokenId);

    // If the bid is not higher, send the
    // money back (the revert statement
    // will revert all changes in this
    // function execution including
    // it having received the money).
    if (
      amount < auction.minimumBid || amount <= auction.winningBid || amount < 1
    ) revert BidNotHighEnough(auction.winningBid);

    if (auction.winningBid != 0) {
      // Sending back the money by simply using
      // highestBidder.send(highestBid) is a security risk
      // because it could execute an untrusted contract.
      // It is always safer to let the recipients
      // withdraw their money themselves.
      pendingReturns[auction.winningBidder] += (auction.winningBid +
        stokingCost(donors[auction.tokenId], tokenId));
      core.safeTransferFrom(
        address(this),
        auction.winningBidder,
        donors[auction.tokenId]
      );
    }
    core.safeTransferFrom(msg.sender, address(this), donor);
    auction.winningBidder = msg.sender;
    auction.winningBid = amount;
    donors[auction.tokenId] = donor;
    emit HighestBidIncreased(tokenId, msg.sender, amount);
  }

  /// Claim the asset being auctioned
  function claim(uint256 tokenId) external override returns (bool success) {
    Auction storage auction = auctions[tokenId];
    if (auction.startTime == 0) revert('Auction does not exist');
    if (!auction.ended) revert AuctionNotYetEnded();
    uint256 donorB = auction.tokenId;
    if (
      msg.sender == auction.winningBidder ||
      msg.sender == auction.beneficiaryAddress
    ) {
      if (auction.winningBidder != address(0x0)) {
        uint256 donorA = donors[donorB];
        (bool stoked, ) = address(core).call{
          value: stokingCost(donorA, donorB)
        }(
          abi.encodeWithSignature('stokeWith(uint256,uint256)', donorA, donorB)
        );
        require(stoked, 'Stoking failed');
        core.safeTransferFrom(address(this), auction.winningBidder, donorA);
      }

      core.safeTransferFrom(address(this), auction.beneficiaryAddress, donorB);
    } else if (auction.winningBidder == address(0x0)) {
      core.safeTransferFrom(address(this), auction.beneficiaryAddress, donorB);
    } else {
      revert('Not the winning bidder or the creator');
    }
    delete auctions[tokenId];
    delete donors[tokenId];
    return true;
  }
}
