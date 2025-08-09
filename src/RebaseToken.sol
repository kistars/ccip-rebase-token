// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RebaseToken is ERC20 {
    error InterestRateCannotBeIncreased(uint256 _newInterestRate, uint256 _currentInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private interestRate = 5e16; // 5%
    mapping(address => uint256) public userInterestRate; // user interest rate
    mapping(address => uint256) public userLastUpdatedTimestamp; // user last updated timestamp

    event InterestRateSet(uint256 _interestRate);
    event UserInterestRateSet(address _user, uint256 _interestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /**
     * @notice Set the interest rate
     * @param _interestRate The new interest rate
     */
    function setInterestRate(uint256 _interestRate) external {
        if (_interestRate > interestRate) {
            revert InterestRateCannotBeIncreased(_interestRate, interestRate);
        }
        interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }

    /**
     * @notice Mint tokens to a user
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        userInterestRate[_to] = interestRate;
        emit UserInterestRateSet(_to, interestRate);
        _mint(_to, _amount);
    }

    /**
     * @notice Get the balance of a user
     * @param _user The address to get the balance of
     * @return The balance of the user
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Calculate the accumulated interest since the last update
     * @param _user The address to calculate the accumulated interest for
     * @return linearInterestRate The accumulated interest
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterestRate)
    {
        // calculate the interest rate since the last update
        uint256 timeElapsed = block.timestamp - userLastUpdatedTimestamp[_user];
        linearInterestRate = (PRECISION_FACTOR + (userInterestRate[_user] * timeElapsed));
    }

    /**
     * @notice Mint the accrued interest to a user
     * @param _user The address to mint the accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        // prev balance
        uint256 prevBalance = super.balanceOf(_user);
        // current balance
        uint256 curBalance = balanceOf(_user);
        // accrued interest
        uint256 accruedInterest = curBalance - prevBalance;
        // update last updated timestamp
        userLastUpdatedTimestamp[_user] = block.timestamp;
        // mint accrued interest
        _mint(_user, accruedInterest);
    }

    /**
     * @notice Burn tokens from a user
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }
}
