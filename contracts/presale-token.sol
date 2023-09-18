// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPinkswapRouter02.sol";
import "./interfaces/IPinkswapFactory.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public startTime;
    uint256 public endTime;
    bool public isPublic;
    uint256 public limitPerWallet;
    uint256 public minimumPerWallet;
    uint256 public tokenPrice;
    uint256 public totalSold;
    bool public refundEnabled;
    IPinkswapRouter02 public addLiquidContract;
    IPinkswapFactory public createPairAddress;
    bool isRefund;
    address immutable WBNB = 0x094616F0BdFB0b526bD735Bf66Eca0Ad254ca81F;
    address public systemAdmin;
    enum State {
        Pending,
        Active,
        Finished,
        Canceled
    }
    State public state;

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public refundAmounts;
    mapping(address => uint256) public claimedAmount;
    mapping(address => bool) public whitelistMap;

    IERC20 public token;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event ClaimedTokens(address indexed user, uint256 amount);
    event RefundedTokens(address indexed user, uint256 amount);
    event Finalize(uint256 timestamp);
    event CancelPool(uint256 at);
    //struct
    struct PresaleInfo {
        address owner;
        uint256 softCap;
        uint256 hardCap;
        uint256 startTime;
        uint256 endTime;
        uint256 tokenPrice;
        uint256 totalSold;
        uint256 userBalance;
    }

    modifier onlyWhitelisted() {
        require(whitelistMap[msg.sender], "You are not whitelisted");
        _;
    }

    modifier canBuyTokens() {
        require(
            isPublic || whitelistMap[msg.sender],
            "You are not authorized to buy tokens"
        );
        _;
    }

    modifier onlyAdminOrOwner() {
        require(
            msg.sender == owner() || systemAdmin == msg.sender,
            "Not the Owner or Admin"
        );
        _;
    }

    constructor(
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime,
        bool _isPublic,
        uint256 _limitPerWallet,
        uint256 _minimumPerWallet,
        uint256 _tokenPrice,
        address _tokenAddress,
        address _addLiquidContract,
        address _createPairAddress,
        address _systemAdmin
    ) {
        softCap = _softCap;
        hardCap = _hardCap;
        startTime = _startTime;
        endTime = _endTime;
        isPublic = _isPublic;
        limitPerWallet = _limitPerWallet;
        minimumPerWallet = _minimumPerWallet;
        tokenPrice = _tokenPrice;

        addLiquidContract = IPinkswapRouter02(_addLiquidContract);
        createPairAddress = IPinkswapFactory(_createPairAddress);
        systemAdmin = _systemAdmin;

        token = IERC20(_tokenAddress);
    }

    function getData(
        address _userAddress
    ) public view returns (PresaleInfo memory) {
        return (
            PresaleInfo(
                owner(),
                softCap,
                hardCap,
                startTime,
                endTime,
                tokenPrice,
                totalSold,
                token.balanceOf(_userAddress)
            )
        );
    }

    // function startPresale() external onlyOwner {
    //     require(
    //         state == State.Pending,
    //         "Presale has already started or finished"
    //     );
    //     state = State.Active;
    // }

    function finishPresale() external onlyOwner {
        require(
            state == State.Active || (refundEnabled && state == State.Pending),
            "Presale has not started or already finished"
        );
        state = State.Finished;
        payable(owner()).transfer(address(this).balance);
    }

    function setPublic(bool _isPublic) external onlyOwner {
        isPublic = _isPublic;
    }

    function isWhitelisted(address user) external view returns (bool) {
        return whitelistMap[user];
    }

    function addWhitelistAddresses(
        address[] calldata users
    ) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            require(!whitelistMap[users[i]], "Address is already whitelisted");
            whitelistMap[users[i]] = true;
        }
    }

    function buyTokens() external payable canBuyTokens nonReentrant {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Presale is not active"
        );
        require(
            contributions[msg.sender] + msg.value <= limitPerWallet,
            "Exceeds limit per wallet"
        );
        require(
            contributions[msg.sender] + msg.value >= minimumPerWallet,
            "Below minimum per wallet"
        );
        require(totalSold + msg.value <= hardCap, "Hard cap reached");

        contributions[msg.sender] += msg.value;
        totalSold += msg.value;
        emit TokensPurchased(msg.sender, msg.value);
    }

    function claimTokens() external nonReentrant {
        require(state == State.Finished, "Presale is not finished");
        require(
            claimedAmount[msg.sender] < contributions[msg.sender],
            "Already claimed"
        );

        uint256 claimableAmount = (contributions[msg.sender] * tokenPrice) /
            1 ether;
        claimedAmount[msg.sender] = contributions[msg.sender];
        contributions[msg.sender] = 0;
        token.safeTransfer(msg.sender, claimableAmount);
        emit ClaimedTokens(msg.sender, claimableAmount);
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function emergencyTokenWithdraw() external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    function burnRemainingTokens() internal {
        uint256 burnAmount = getRemainingTokensToHardCap();
        if (burnAmount > 0) {
            token.transfer(address(0), burnAmount);
        }
    }

    function refundLaunchpadTokenToOwner() internal {
        uint256 refundAmount = getRemainingTokensToHardCap();
        if (refundAmount > 0) {
            token.transfer(msg.sender, refundAmount);
        }
    }

    function getRemainingTokensToHardCap() public view returns (uint256) {
        uint256 soldTokens = (totalSold * tokenPrice) / 1 ether;
        uint256 maxTokens = (hardCap * tokenPrice) / 1 ether;

        if (soldTokens >= maxTokens) {
            return 0;
        }
        return (maxTokens - soldTokens);
    }

    function enableRefunds() external onlyOwner {
        require(
            state == State.Pending,
            "Refunds can only be enabled in the pending state"
        );
        refundEnabled = true;
    }

    function refundTokens() external nonReentrant {
        require(refundEnabled, "Refunds are not enabled");
        require(state != State.Finished, "Presale is finished");
        require(contributions[msg.sender] > 0, "No contribution to refund");
        uint256 refundableAmount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        refundAmounts[msg.sender] = refundableAmount;
        totalSold -= refundableAmount;
        payable(msg.sender).transfer(refundableAmount);
        emit RefundedTokens(msg.sender, refundableAmount);
    }

    function isFinalized() public view returns (bool) {
        if (state == State.Pending) {
            return (block.timestamp >= endTime ||
                totalSold >= softCap ||
                totalSold == hardCap);
        } else {
            return false;
        }
    }

    //deadline = now + lock time
    function finalize(
        uint8 _liquidPercent,
        uint256 _deadline,
        uint256 _listingRate
    ) public payable nonReentrant onlyAdminOrOwner {
        require(isFinalized(), "can not finalize");
        uint256 ETHAddLiquid = (address(this).balance * (_liquidPercent)) / 100;
        uint256 refundToOwnerAmount = (address(this).balance *
            (100 - _liquidPercent)) / 100;
        uint256 amountTokenAddLiquid = ((totalSold *
            tokenPrice *
            _listingRate *
            _liquidPercent) / 100) / (1 ether);
        //handle transfer token to contract this
        token.transferFrom(msg.sender, address(this), amountTokenAddLiquid);
        //handle create pair
        createPairAddress.createPair(WBNB, address(token));
        token.approve(address(addLiquidContract), amountTokenAddLiquid);
        //handle add liquid
        require(
            51 <= _liquidPercent && _liquidPercent <= 100,
            "invalid liquidity percent"
        );

        addLiquidContract.addLiquidityETH{value: ETHAddLiquid}(
            address(token),
            amountTokenAddLiquid,
            0,
            0,
            owner(),
            _deadline
        );

        //handle finalize
        state = State.Finished;
        payable(owner()).transfer(refundToOwnerAmount);
        emit Finalize(block.timestamp);
    }

    function cancelPresale() external onlyAdminOrOwner {
        state = State.Canceled;
        refundEnabled = true;
        emit CancelPool(block.timestamp);
    }

    function withDrawOrBurn(bool _isRefund) public onlyOwner {
        if (_isRefund) {
            refundLaunchpadTokenToOwner();
        } else {
            burnRemainingTokens();
        }
    }

    function getLiquidAmount(
        uint8 _liquidPercent,
        uint256 _listingRate
    ) public view returns (uint256) {
        return
            ((totalSold * tokenPrice * _listingRate * _liquidPercent) / 100) /
            (1 ether);
    }
}
