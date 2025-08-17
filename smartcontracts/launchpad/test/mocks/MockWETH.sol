// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function allowance(address,address) external view returns (uint256);
    function approve(address,uint256) external returns (bool);
    function transfer(address,uint256) external returns (bool);
    function transferFrom(address,address,uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

contract MockWETH is IERC20Minimal {
    string public name = "Mock WETH";
    string public symbol = "WETH";
    uint8 public constant _decimals = 18;

    mapping(address => uint256) private _bal;
    mapping(address => mapping(address => uint256)) private _allow;

    function decimals() external pure returns (uint8) { return _decimals; }

    function balanceOf(address a) external view returns (uint256) { return _bal[a]; }

    function allowance(address o, address s) external view returns (uint256) { return _allow[o][s]; }

    function approve(address s, uint256 v) external returns (bool) {
        _allow[msg.sender][s] = v; return true;
    }

    function transfer(address to, uint256 v) external returns (bool) {
        require(_bal[msg.sender] >= v, "BAL");
        _bal[msg.sender] -= v; _bal[to] += v; return true;
    }

    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        uint256 a = _allow[f][msg.sender]; require(a >= v, "ALLOW");
        require(_bal[f] >= v, "BAL");
        if (a != type(uint256).max) { _allow[f][msg.sender] = a - v; }
        _bal[f] -= v; _bal[t] += v; return true;
    }

    function mint(address to, uint256 v) external {
        _bal[to] += v;
    }
} 