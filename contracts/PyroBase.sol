// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import './Pyro.sol';
import './token/Embers.sol';
import './token/MRC721.sol';

contract PyroBase is MRC721 {
  Embers public immutable embers;
  string public baseURI;

  uint32 public constant gen0Cap = 2**14;
  uint256 public generationCost;
  uint256 public stokingBaseCost;

  uint256[14] public pyroGenesisCosts;

  uint32[14] public pyroGenesisCooldowns;

  uint32 public gen0Count;

  Pyro[] public pyros;

  mapping(uint256 => address) public stokingAllowedToAddress;

  mapping(uint256 => uint256) public lastPlayed;

  mapping(uint256 => uint256) public lastAte;

  mapping(uint256 => uint256) public pyroLevel;

  event Ignition(
    uint256 tokenId,
    string name,
    uint256 donorA,
    uint256 donorB,
    address indexed owner
  );

  uint8[14] public emberRates = [
    uint8(70),
    uint8(47),
    uint8(35),
    uint8(28),
    uint8(23),
    uint8(20),
    uint8(18),
    uint8(16),
    uint8(14),
    uint8(13),
    uint8(12),
    uint8(11),
    uint8(10),
    uint8(9)
  ];

  constructor(
    string memory _uri,
    uint256 _generationCost,
    uint256 _stokingBaseCost,
    uint256 _timeUnit
  ) MRC721('PyroPets', 'PYRO') {
    baseURI = _uri;
    generationCost = _generationCost;
    stokingBaseCost = _stokingBaseCost;
    embers = new Embers(address(this));
    pyroGenesisCosts = [
      uint256(stokingBaseCost / 8),
      uint256(stokingBaseCost / 7),
      uint256(stokingBaseCost / 6),
      uint256(stokingBaseCost / 5),
      uint256(stokingBaseCost / 4),
      uint256(stokingBaseCost / 3),
      uint256(stokingBaseCost / 2),
      uint256(stokingBaseCost),
      uint256(stokingBaseCost * 2),
      uint256(stokingBaseCost * 3),
      uint256(stokingBaseCost * 4),
      uint256(stokingBaseCost * 5),
      uint256(stokingBaseCost * 6),
      uint256(stokingBaseCost * 7)
    ];
    pyroGenesisCooldowns = [
      uint32(35 * _timeUnit),
      uint32(28 * _timeUnit),
      uint32(23 * _timeUnit),
      uint32(20 * _timeUnit),
      uint32(18 * _timeUnit),
      uint32(16 * _timeUnit),
      uint32(14 * _timeUnit),
      uint32(13 * _timeUnit),
      uint32(12 * _timeUnit),
      uint32(11 * _timeUnit),
      uint32(10 * _timeUnit),
      uint32(9 * _timeUnit),
      uint32(8 * _timeUnit),
      uint32(7 * _timeUnit)
    ];
  }

  /**
   * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
   * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
   * by default, can be overriden in child contracts.
   */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function generationOfPyro(uint256 tokenId) public view returns (uint256) {
    require(ownerOf(tokenId) != address(0x0));
    return pyros[tokenId].generation;
  }

  function getPyro(uint256 id)
    public
    view
    returns (
      uint256 donorA,
      uint256 donorB,
      uint256 generation,
      string memory name,
      uint256 ignitionTime,
      uint256 nextPyroGenesis,
      uint256 pyroGenesisCount,
      uint256 stokingWith,
      uint8 hunger,
      uint8 eyes,
      uint8 snout,
      uint8 color
    )
  {
    Pyro memory pyro = pyros[id];
    return (
      pyro.donorA,
      pyro.donorB,
      pyro.generation,
      pyro.name,
      pyro.ignitionTime,
      pyro.nextPyroGenesis,
      pyro.pyroGenesisCount,
      pyro.stokingWith,
      pyro.hunger,
      pyro.eyes,
      pyro.snout,
      pyro.color
    );
  }

  function _createRootPyro(string memory _name, address _owner)
    internal
    returns (uint256)
  {
    uint8 eyes = 0;
    uint8 snout = 0;
    Pyro memory pyro = Pyro({
      donorA: 0,
      donorB: 0,
      generation: 0,
      name: _name,
      ignitionTime: block.timestamp,
      nextPyroGenesis: pyroGenesisCooldowns[0],
      pyroGenesisCount: 0,
      stokingWith: 0,
      hunger: 255,
      eyes: eyes,
      snout: snout,
      color: 0x00
    });

    pyros.push(pyro);
    uint256 tokenId = pyros.length - 1;
    emit Ignition(tokenId, _name, 0, 0, _owner);
    _safeMint(_owner, tokenId);
    gen0Count++;
    return tokenId;
  }

  function _createPyro(
    uint256 _donorA,
    uint256 _donorB,
    uint256 _generation,
    string memory _name,
    address _owner
  ) internal returns (uint256) {
    Pyro storage donorA = pyros[_donorA];
    Pyro storage donorB = pyros[_donorB];
    uint8 eyes = donorA.generation <= donorB.generation
      ? donorA.eyes
      : donorB.eyes;
    uint8 snout = donorB.generation <= donorA.generation
      ? donorB.snout
      : donorA.snout;
    if (_generation == 0) {
      require(gen0Count + 1 <= gen0Cap);
      gen0Count++;
      bytes32 genes = keccak256(
        abi.encodePacked(
          block.timestamp,
          block.difficulty,
          blockhash(block.number),
          _name,
          _owner,
          pyros.length
        )
      );

      eyes = uint8(genes[0]) % 32;
      snout = uint8(genes[31]) % 32;
    }

    Pyro memory pyro = Pyro({
      donorA: _donorA,
      donorB: _donorB,
      generation: _generation,
      name: _name,
      ignitionTime: block.timestamp,
      nextPyroGenesis: block.timestamp,
      pyroGenesisCount: 0,
      stokingWith: 0,
      hunger: 255,
      eyes: eyes,
      snout: snout,
      color: 0x00
    });

    pyros.push(pyro);

    uint256 tokenId = pyros.length - 1;
    lastAte[tokenId] = block.timestamp;
    emit Ignition(tokenId, _name, _donorA, _donorB, _owner);
    _safeMint(_owner, tokenId);
    return tokenId;
  }

  function burn(uint256 tokenId) public override {
    _burnPyro(tokenId);
    super.burn(tokenId);
  }

  function _burnPyro(uint256 tokenId) internal {
    Pyro storage pyro = pyros[tokenId];
    require(_isApprovedOrOwner(_msgSender(), tokenId));
    if (pyro.generation == 0) {
      gen0Count--;
    }
    uint8 emberRate = emberRates[pyro.generation > 13 ? 13 : pyro.generation];
    uint256 amount = ((emberRate * (pyroLevel[tokenId] + 1)) /
      (pyro.generation + 1)) * 10;
    (bool success, ) = address(embers).call(
      abi.encodeWithSignature(
        'generateEmbers(uint256,uint256)',
        tokenId,
        amount
      )
    );
    require(success);
    delete pyros[tokenId];
    delete lastAte[tokenId];
    delete lastPlayed[tokenId];
    delete pyroLevel[tokenId];
  }

  /**
   * @dev See {MRC721-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev See {MRC721-_beforeTokenTransfer}.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(MRC721) {
    super._beforeTokenTransfer(from, to, tokenId);
    delete stokingAllowedToAddress[tokenId];
  }

  function play(uint256 tokenId) public {
    Pyro storage pyro = pyros[tokenId];
    require(_isApprovedOrOwner(_msgSender(), tokenId));
    require(lastPlayed[tokenId] + 1 days <= block.timestamp);
    require(pyro.hunger > 0);
    (bool success, ) = address(embers).call{value: 0}(
      abi.encodeWithSignature(
        'generateEmbers(uint256,uint256)',
        tokenId,
        uint256(emberRates[pyro.generation > 13 ? 13 : pyro.generation])
      )
    );
    require(success);
    pyroLevel[tokenId] += 1;
    pyro.hunger -= 1;
    lastPlayed[tokenId] = block.timestamp;
  }

  function feed(uint256 tokenId, uint8 amount) public {
    Pyro storage pyro = pyros[tokenId];
    require(pyro.hunger < 255);
    require(_isApprovedOrOwner(_msgSender(), tokenId));

    uint256 allowance = embers.allowance(_msgSender(), address(this));
    require(allowance >= uint256(amount));
    uint256 balance = embers.balanceOf(_msgSender());
    require(balance >= uint256(amount));
    embers.burnFrom(_msgSender(), uint256(amount));
    require(embers.balanceOf(_msgSender()) == balance - uint256(amount));
    pyroLevel[tokenId] += 1;
    pyro.hunger += uint8(amount > 0xff ? 0xff : amount);
  }

  function setColor(uint256 tokenId, uint8 color) public {
    Pyro storage pyro = pyros[tokenId];
    require(_isApprovedOrOwner(_msgSender(), tokenId));
    require(color <= 7);
    uint256 allowance = embers.allowance(_msgSender(), address(this));
    require(allowance >= 100);
    uint256 balance = embers.balanceOf(_msgSender());
    require(balance >= 100);
    embers.burnFrom(_msgSender(), 100);
    require(embers.balanceOf(_msgSender()) == balance - 100);
    pyro.color = color;
  }

  function setName(uint256 tokenId, string calldata name) public {
    Pyro storage pyro = pyros[tokenId];
    require(_isApprovedOrOwner(_msgSender(), tokenId));
    uint256 allowance = embers.allowance(_msgSender(), address(this));
    require(allowance >= 100);
    uint256 balance = embers.balanceOf(_msgSender());
    require(balance >= 100);
    embers.burnFrom(_msgSender(), 100);
    require(embers.balanceOf(_msgSender()) == balance - 100);
    pyro.name = name;
  }

  function levelUp(uint256 tokenId, uint256 amount) public {
    require(_isApprovedOrOwner(_msgSender(), tokenId));
    uint256 allowance = embers.allowance(_msgSender(), address(this));
    require(allowance >= amount);
    uint256 balance = embers.balanceOf(_msgSender());
    require(balance >= amount);
    embers.burnFrom(_msgSender(), amount);
    require(embers.balanceOf(_msgSender()) == balance - amount);
    pyroLevel[tokenId] += amount;
  }
}
