// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import './PyroGenesis.sol';
import './auction/Auction.sol';
import './auction/SaleAuction.sol';
import './auction/StokingAuction.sol';

contract PyroAuction is PyroGenesis {
  SaleAuction public immutable saleAuction;
  StokingAuction public immutable stokingAuction;

  constructor(
    string memory _uri,
    uint256 _generationCost,
    uint256 _stokingBaseCost,
    uint256 _timeUnit
  ) PyroGenesis(_uri, _generationCost, _stokingBaseCost, _timeUnit) {
    saleAuction = new SaleAuction(address(this));
    stokingAuction = new StokingAuction(address(this));
  }

  function getSaleAuction(uint256 _tokenId)
    public
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
    )
  {
    return saleAuction.getAuction(_tokenId);
  }

  function getStokingAuction(uint256 _tokenId)
    public
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
    )
  {
    return stokingAuction.getAuction(_tokenId);
  }
}
