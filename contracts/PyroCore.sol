// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import './token/Embers.sol';
import './PyroAuction.sol';

contract PyroCore is PyroAuction {
  constructor(
    string memory _uri,
    uint256 _generationCost,
    uint256 _stokingBaseCost,
    uint256 _timeUnit
  ) PyroAuction(_uri, _generationCost, _stokingBaseCost, _timeUnit) {
    _createRootPyro('Agni', address(this));
  }
}
