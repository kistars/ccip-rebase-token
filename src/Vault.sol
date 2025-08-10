// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    address private immutable REBASE_TOKEN;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(address _rebaseToken) {
        REBASE_TOKEN = _rebaseToken;
    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }

    /**
     * @notice Deposit ETH into the vault
     * @dev The ETH is minted as rebase tokens
     */
    function deposit() public payable {
        IRebaseToken(REBASE_TOKEN).mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeem rebase tokens for ETH
     * @dev The ETH is transferred to the caller
     * @param _amount The amount of rebase tokens to redeem
     */
    function redeem(uint256 _amount) external {
        IRebaseToken(REBASE_TOKEN).burn(msg.sender, _amount);
        // transfer the ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the address of the rebase token
     * @dev This is used to get the address of the rebase token
     * @return The address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return REBASE_TOKEN;
    }
}
