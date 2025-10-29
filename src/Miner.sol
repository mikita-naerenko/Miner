//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
/**
 * @title Miner
 * @notice Simulates an on-chain “mining” economy where users can buy, compound, and sell “units”.
 *         The system includes a referral mechanism and a developer fee that is sent to a
 *         payment splitter contract.
 *
 * @dev 
 * Core mechanics:
 * - `buyUnits()`: users purchase mining units using ETH.
 * - `compoundUnits()`: converts accumulated units into new “miners” that produce more units over time.
 * - `sellUnits()`: sells accumulated units back for ETH, applying a developer fee.
 * - `initializeMarket()`: one-time setup of the market before use.
 * - Referral rewards are distributed when users compound or buy with a referral address.
 * - Developer fee is calculated and transferred to the `splitter` address.
 * - Uses `ReentrancyGuard` to prevent recursive `sellUnits()` calls.
 * - Owner-only functions are protected by `Ownable`.
 *
 * @notice This contract is intended for simulation or game-like use cases and
 *         does not implement real mining or token issuance.
 * 
 * @dev Key constants:
 * - `UNITS_TO_CREATE_PRODUCER`: number of units required to create a new miner.
 * - `PRICE_SCALE`: precision factor for trade calculations.
 * - `DEV_FEE_VAL`: developer fee percentage (5%).
 *
 * Mappings:
 * - `hatcheryMiners`: number of miners owned per address.
 * - `claimedUnits`: stored but unclaimed units per address.
 * - `referrals`: registered referral address for each user.
 *
 * Events:
 * - `BuyUnits`: emitted on purchases.
 * - `CompoundUnits`: emitted on compounding actions.
 * - `SoldUnits`: emitted on unit sales.
 * - `ReferralSet` and `ReferralRewarded`: emitted for referral tracking.
 */


contract Miner is Ownable, ReentrancyGuard {
    uint256 private constant UNITS_TO_CREATE_PRODUCER = 1080000; //for final version should be seconds in a day
    uint256 private constant PRICE_SCALE = 10000;
    uint256 private constant PRICE_SCALE_HALF = 5000;
    uint256 private constant REFERRAL_DIVISOR = 8;
    uint256 private constant MARKET_BOOST_DIVISOR = 5;
    uint256 private constant DEV_FEE_VAL = 5;
    bool private initialized = false;
    address payable public splitter;
    mapping(address => uint256) private hatcheryMiners;
    mapping(address => uint256) private claimedUnits;
    mapping(address => uint256) private lastHatch;
    mapping(address => address) private referrals;
    uint256 private marketUnits;

    event BuyUnits(
        address indexed buyer,
        uint256 paid,
        uint256 unitsBought,
        uint256 fee,
        address indexed ref,
        uint256 timestamp
    );
    event CompoundUnits(
        address indexed user,
        uint256 unitsUsed,
        uint256 newProducers,
        uint256 marketBoost,
        uint256 timestamp
    );
    event SoldUnits(
        address indexed seller,
        uint256 unitsSold,
        uint256 grossValue,
        uint256 fee,
        uint256 timestamp
    );

    event ReferralSet(
        address indexed user,
        address indexed ref,
        uint256 timestamp
    );
    event ReferralRewarded(
        address indexed referrer,
        address indexed from,
        uint256 units,
        uint256 timestamp
    );

    constructor(address payable _splitter) {
        require(_splitter != address(0), "zero splitter");
        splitter = _splitter;
    }

    function compoundUnits(address ref) public {
        require(initialized);

        _setRef(msg.sender, ref);

        uint256 unitsUsed = balanceOf(msg.sender);
        uint256 newMiners = unitsUsed / UNITS_TO_CREATE_PRODUCER;
        hatcheryMiners[msg.sender] += newMiners;
        claimedUnits[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;

        address referrer = referrals[msg.sender];
        if (referrer != address(0)) {
            uint256 reward = unitsUsed / REFERRAL_DIVISOR;
            claimedUnits[referrer] = claimedUnits[referrer] + reward;
            emit ReferralRewarded(
                referrer,
                msg.sender,
                reward,
                block.timestamp
            );
        }

        uint256 marketBoost = unitsUsed / MARKET_BOOST_DIVISOR;
        marketUnits += marketBoost;

        emit CompoundUnits(
            msg.sender,
            unitsUsed,
            newMiners,
            marketBoost,
            block.timestamp
        );
    }

    function sellUnits() public nonReentrant {
        require(initialized);

        uint256 hasUnits = balanceOf(msg.sender);
        require(hasUnits > 0, "no units");
        uint256 unitValue = estimateRedemption(hasUnits);
        require(unitValue > 0, "zero value");
        uint256 fee = devFee(unitValue);

        claimedUnits[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketUnits += hasUnits;

        require(splitter != payable(address(0)), "splitter not set");
        (bool ok, ) = payable(splitter).call{value: fee}("");
        require(ok, "splitter transfer failed");

        uint256 payout = unitValue - fee;
        (bool paid, ) = payable(msg.sender).call{value: payout}("");
        require(paid, "payout failed");

        emit SoldUnits(msg.sender, hasUnits, unitValue, fee, block.timestamp);
    }

    function pendingRewardsOf(address adr) public view returns (uint256) {
        uint256 hasUnits = balanceOf(adr);
        uint256 unitValue = estimateRedemption(hasUnits);
        return unitValue;
    }

    function buyUnits(address ref) public payable nonReentrant {
        require(initialized && msg.value > 0);
        uint256 contractBalBefore = address(this).balance - msg.value;
        uint256 fee = devFee(msg.value);
        uint256 netValue = msg.value - fee;
        uint256 unitsBought = estimatePurchase(netValue, contractBalBefore);

        claimedUnits[msg.sender] = claimedUnits[msg.sender] + unitsBought;
        compoundUnits(ref);

        if (fee > 0) {
            (bool sent, ) = splitter.call{value: fee}("");
            require(sent, "splitter transfer failed");
        }

        emit BuyUnits(
            msg.sender,
            msg.value,
            unitsBought,
            fee,
            ref,
            block.timestamp
        );
    }

    function calculateTrade(
        uint256 rt,
        uint256 rs,
        uint256 bs
    ) private pure returns (uint256) {
        if (rt == 0) return 0;
        uint256 numer = PRICE_SCALE * bs;
        uint256 part = (PRICE_SCALE * rs + PRICE_SCALE_HALF * rt) / rt;
        uint256 denom = PRICE_SCALE_HALF + part;

        return numer / denom;
    }

    function estimateRedemption(uint256 eggs) public view returns (uint256) {
        return calculateTrade(eggs, marketUnits, address(this).balance);
    }

    function estimatePurchase(
        uint256 eth,
        uint256 contractBalance
    ) public view returns (uint256) {
        return calculateTrade(eth, contractBalance, marketUnits);
    }

    function estimatePurchaseSimple(uint256 eth) public view returns (uint256) {
        return estimatePurchase(eth, address(this).balance);
    }

    function devFee(uint256 amount) private pure returns (uint256) {
        return (amount * DEV_FEE_VAL) / 100;
    }

    function initializeMarket() public onlyOwner {
        require(marketUnits == 0);
        initialized = true;
        marketUnits = 108000000000;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function minersOf(address adr) public view returns (uint256) {
        return hatcheryMiners[adr];
    }

    function balanceOf(address adr) public view returns (uint256) {
        return claimedUnits[adr] + accruedUnitsOf(adr);
    }

    function accruedUnitsOf(address adr) public view returns (uint256) {
        uint256 secondsPassed = min(
            UNITS_TO_CREATE_PRODUCER,
            block.timestamp - lastHatch[adr]
        );
        return secondsPassed * hatcheryMiners[adr];
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _setRef(address user, address ref) internal {
        if (ref == user) {
            ref = address(0);
        }

        if (referrals[user] == address(0) && referrals[user] != user) {
            referrals[user] = ref;
            emit ReferralSet(user, ref, block.timestamp);
        }
    }
}
