// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../PyroBase.sol";
import "./MRC20.sol";
import "./MRC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Embers is MRC20, MRC20Burnable {
    uint256 public constant minBurn = 1e11;

    address public immutable base;

    constructor(address _base) MRC20("Embers", "MBRS") {
        base = _base;
    }

    function createEmbers() public payable {
        require(msg.value >= minBurn);
        uint256 amount = msg.value / 1e11;
        require(amount > 0);
        payable(address(0x0)).transfer(msg.value);
        _mint(msg.sender, amount);
    }

    function generateEmbers(uint256 id, uint256 amount) external {
        require(msg.sender == base);
        PyroBase _base = PyroBase(base);
        address owner = _base.ownerOf(id);
        _mint(owner, amount);
    }

    receive() external payable {
        createEmbers();
    }

    fallback() external payable {
        createEmbers();
    }

    function mint() public payable {
        createEmbers();
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
}
