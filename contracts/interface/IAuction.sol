// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import '../auction/Auction.sol';

interface IAuction {
  function createAuction(
    uint256 tokenId,
    uint256 minimumBid,
    uint256 biddingTime,
    address payable beneficiaryAddress
  ) external returns (bool success);

  function withdraw() external returns (bool success);

  function claim(uint256 tokenId) external returns (bool success);

  function cancelAuction(uint256 tokenId) external returns (bool success);

  function auctionEnd(uint256 tokenId) external;

  function getAuction(uint256 _tokenId)
    external
    view
    returns (
      uint256 tokenId,
      uint256 winningBid,
      uint256 minimumBid,
      uint256 biddingTime,
      uint256 startTime,
      address winningBidder,
      address payable beneficiaryAddress,
      bool ended
    );
}
