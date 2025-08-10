// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    error InterestRateCannotBeIncreased(uint256 _newInterestRate, uint256 _currentInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 public interestRate = 5e10; // 5%
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    mapping(address => uint256) public userInterestRate; // user interest rate
    mapping(address => uint256) public userLastUpdatedTimestamp; // user last updated timestamp

    event InterestRateSet(uint256 _interestRate);
    event UserInterestRateSet(address _user, uint256 _interestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Grant the mint and burn role to an address
     * @param _to The address to grant the mint and burn role to
     */
    function grantMintAndBurnRole(address _to) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _to);
    }

    /**
     * @notice Set the interest rate
     * @param _interestRate The new interest rate
     */
    function setInterestRate(uint256 _interestRate) external onlyOwner {
        if (_interestRate > interestRate) {
            revert InterestRateCannotBeIncreased(_interestRate, interestRate);
        }
        interestRate = _interestRate;
        emit InterestRateSet(_interestRate);
    }

    /**
     * @notice Get the principal balance of a user not including any interest
     * @param _user The address to get the principal balance of
     * @return The principal balance of the user
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint tokens to a user
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
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
     * @notice Transfer tokens to a user
     * @param _to The address to transfer tokens to
     * @param _amount The amount of tokens to transfer
     * @return bool True if the transfer is successful
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_to) == 0) {
            userInterestRate[_to] = userInterestRate[msg.sender];
            emit UserInterestRateSet(_to, userInterestRate[msg.sender]);
        }
        return super.transfer(_to, _amount);
    }

    /**
     * @notice Transfer tokens from a user to another user
     * @param _from The address to transfer tokens from
     * @param _to The address to transfer tokens to
     * @param _amount The amount of tokens to transfer
     * @return bool True if the transfer is successful
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        if (balanceOf(_to) == 0) {
            userInterestRate[_to] = userInterestRate[_from];
            emit UserInterestRateSet(_to, userInterestRate[_from]);
        }
        return super.transferFrom(_from, _to, _amount);
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
        uint256 timeElapsed;
        if (userLastUpdatedTimestamp[_user] == 0) {
            // First time user interacts, no interest accumulated yet
            timeElapsed = 0;
        } else {
            timeElapsed = block.timestamp - userLastUpdatedTimestamp[_user];
        }

        // Calculate annual interest rate: interestRate is in basis points (1e10 = 100%)
        // For 5% annual rate: 5e10 / 1e10 = 0.05
        // Convert to per-second rate: 0.05 / (365 * 24 * 3600) = 0.05 / 31536000
        // Use PRECISION_FACTOR (1e27) for precision
        uint256 annualRate = userInterestRate[_user];
        uint256 perSecondRate = (annualRate * PRECISION_FACTOR) / (365 days);

        // Calculate accumulated interest: 1 + (rate * time)
        linearInterestRate = PRECISION_FACTOR + (perSecondRate * timeElapsed);
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
        if (accruedInterest > 0) {
            _mint(_user, accruedInterest);
        }
    }

    /**
     * @notice Burn tokens from a user
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }
}
