// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import './PyroBase.sol';

contract PyroGenesis is PyroBase {
  event FlareUp(address owner, uint256 donorA, uint256 donorB);

  mapping(address => uint256) public lastGen0Mints;

  constructor(
    string memory _uri,
    uint256 _generationCost,
    uint256 _stokingBaseCost,
    uint256 _timeUnit
  ) PyroBase(_uri, _generationCost, _stokingBaseCost, _timeUnit) {}

  function generationZero(string calldata name) public payable {
    require(msg.value >= generationCost);
    require(
      block.timestamp >= lastGen0Mints[_msgSender()] + pyroGenesisCooldowns[0]
    );
    (bool burned, ) = payable(address(0x0)).call{value: generationCost}('');
    require(burned);
    if (msg.value - generationCost > 0) {
      (bool refunded, ) = payable(address(_msgSender())).call{
        value: msg.value - generationCost
      }('');
      require(refunded);
    }
    _createPyro(0, 0, 0, name, _msgSender());
    lastGen0Mints[_msgSender()] = block.timestamp;
  }

  function generationZeroForAddress(string calldata name, address owner)
    public
    payable
  {
    require(msg.value >= generationCost);
    require(
      block.timestamp >= lastGen0Mints[_msgSender()] + pyroGenesisCooldowns[0]
    );
    payable(address(0x0)).transfer(generationCost);
    if (msg.value - generationCost > 0) {
      payable(address(_msgSender())).transfer(msg.value - generationCost);
    }
    _createPyro(0, 0, 0, name, owner);
    lastGen0Mints[owner] = block.timestamp;
  }

  function _triggerCooldown(Pyro storage pyro) internal {
    pyro.nextPyroGenesis = uint64(
      block.timestamp +
        pyroGenesisCooldowns[
          pyro.pyroGenesisCount >= 13 ? 13 : pyro.pyroGenesisCount
        ]
    );
    pyro.pyroGenesisCount += 1;
    pyro.hunger = 127;
  }

  function approveStoking(address addr, uint256 donor) public {
    require(ownerOf(donor) == _msgSender());
    stokingAllowedToAddress[donor] = addr;
  }

  function canStokeWith(uint256 _donorA, uint256 _donorB)
    public
    view
    returns (bool)
  {
    require(_donorA > 0);
    require(_donorB > 0);
    Pyro storage donorA = pyros[_donorA];
    Pyro storage donorB = pyros[_donorB];
    return
      _isValidStokingPair(donorA, _donorA, donorB, _donorB) &&
      _isStokingPermitted(_donorB, _donorA);
  }

  function isValidStokingPair(uint256 _donorAId, uint256 _donorBId)
    public
    view
    returns (bool)
  {
    Pyro storage _donorA = pyros[_donorAId];
    Pyro storage _donorB = pyros[_donorBId];
    return _isValidStokingPair(_donorA, _donorAId, _donorB, _donorBId);
  }

  function _isValidStokingPair(
    Pyro storage _donorA,
    uint256 _donorAId,
    Pyro storage _donorB,
    uint256 _donorBId
  ) private view returns (bool) {
    // same pyro
    if (_donorAId == _donorBId) {
      return false;
    }

    //  donorB parent of donorA
    if (_donorA.donorA == _donorBId || _donorA.donorB == _donorBId) {
      return false;
    }
    //  donorA parent of donorB
    if (_donorB.donorA == _donorAId || _donorB.donorB == _donorAId) {
      return false;
    }
    //   gen0 donors parent
    if ((_donorA.donorB == 0 && _donorA.donorA == 0)) {
      return true;
    }

    //  siblings
    if (_donorB.donorA == _donorA.donorA || _donorB.donorA == _donorA.donorB) {
      return false;
    }
    if (_donorB.donorB == _donorA.donorA || _donorB.donorB == _donorA.donorB) {
      return false;
    }

    return true;
  }

  function _isStokingPermitted(uint256 donorA, uint256 donorB)
    internal
    view
    returns (bool)
  {
    address aOwner = ownerOf(donorA);
    address bOwner = ownerOf(donorB);
    return (aOwner == bOwner || stokingAllowedToAddress[donorB] == aOwner);
  }

  function _isReadyToStoke(Pyro storage _pyro) internal view returns (bool) {
    return
      (_pyro.hunger == 0xff) &&
      (_pyro.stokingWith == 0) &&
      (_pyro.nextPyroGenesis <= block.timestamp);
  }

  function _isReadyToIgnite(Pyro storage _pyro) private view returns (bool) {
    return
      (_pyro.hunger == 0xff) &&
      (_pyro.stokingWith != 0) &&
      (_pyro.nextPyroGenesis <= block.timestamp);
  }

  function _stokeWith(uint256 _donorA, uint256 _donorB) internal {
    Pyro storage donorA = pyros[_donorA];
    Pyro storage donorB = pyros[_donorB];

    donorA.stokingWith = _donorB;

    _triggerCooldown(donorA);
    _triggerCooldown(donorB);

    delete stokingAllowedToAddress[_donorA];

    emit FlareUp(ownerOf(_donorA), _donorA, _donorB);
  }

  function stokeWith(uint256 _donorA, uint256 _donorB) public payable {
    require(
      (ownerOf(_donorA) == _msgSender() ||
        stokingAllowedToAddress[_donorA] == msg.sender) &&
        ownerOf(_donorB) == _msgSender()
    );

    require(_isStokingPermitted(_donorA, _donorB));

    Pyro storage donorA = pyros[_donorA];

    require(_isReadyToStoke(donorA));

    Pyro storage donorB = pyros[_donorB];

    require(_isReadyToStoke(donorB));

    require(_isValidStokingPair(donorA, _donorA, donorB, _donorB));

    uint256 generation = donorA.generation > donorB.generation
      ? donorA.generation
      : donorB.generation;
    uint256 cost = pyroGenesisCosts[generation > 13 ? 13 : generation];
    require(msg.value >= cost);

    (bool burned, ) = payable(address(0x0)).call{value: cost}('');
    require(burned);
    if (msg.value - cost > 0) {
      (bool refunded, ) = payable(address(msg.sender)).call{
        value: msg.value - cost
      }('');
      require(refunded);
    }
    _stokeWith(_donorA, _donorB);
  }

  function canStoke(uint256 tokenId) public view returns (bool) {
    Pyro storage pyro = pyros[tokenId];
    return _isReadyToStoke(pyro);
  }

  function ignite(uint256 _pyro, string calldata _name)
    public
    returns (uint256)
  {
    Pyro storage donorA = pyros[_pyro];
    require(donorA.ignitionTime != 0);

    require(_isReadyToIgnite(donorA));

    uint256 _donorB = donorA.stokingWith;
    Pyro storage donorB = pyros[_donorB];

    uint256 gen = donorA.generation > donorB.generation
      ? donorA.generation + 1
      : donorB.generation + 1;

    address owner = ownerOf(_pyro);
    uint256 pyroId = _createPyro(_pyro, _donorB, gen, _name, owner);

    delete donorA.stokingWith;

    return pyroId;
  }
}
