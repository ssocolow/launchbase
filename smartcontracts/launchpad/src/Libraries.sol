// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Interfaces.sol";

library SafeERC20 {
    function safeTransfer(IERC20 t, address to, uint256 amt) internal {
        require(t.transfer(to, amt), "TRANSFER_FAIL");
    }
    function safeTransferFrom(IERC20 t, address from, address to, uint256 amt) internal {
        require(t.transferFrom(from, to, amt), "TRANSFERFROM_FAIL");
    }
    function safeApprove(IERC20 t, address sp, uint256 amt) internal {
        require(t.approve(sp, amt), "APPROVE_FAIL");
    }
}

//basically a middleware lock to prevent reentrancy
abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status == 1, "REENTRANT");
        _status = 2;
        _;
        _status = 1;
    }
}
