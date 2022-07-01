// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

struct Auction {
    uint256 tokenId;
    uint256 winningBid;
    uint256 minimumBid;
    uint256 biddingTime;
    uint256 startTime;
    address winningBidder;
    address payable beneficiaryAddress;
    bool ended;
}
