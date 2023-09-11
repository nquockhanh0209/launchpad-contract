// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPinkswapRouter02.sol";
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
        address _addLiquidContract
    ) {
        softCap = _softCap;
        hardCap = _hardCap;
        startTime = _startTime;
        endTime = _endTime;
        isPublic = _isPublic;
        limitPerWallet = _limitPerWallet;
        minimumPerWallet = _minimumPerWallet;
        tokenPrice = _tokenPrice;
        state = State.Pending;
        addLiquidContract = IPinkswapRouter02(_addLiquidContract);

        // Transfer tokens from the deployer to the contract
        token = IERC20(_tokenAddress);
    }

    function getData(address _userAddress) public view returns (PresaleInfo memory) {
        return(PresaleInfo(owner(), softCap, hardCap, startTime, endTime, tokenPrice, totalSold, token.balanceOf(_userAddress)));
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

    function cancelPresale() external onlyOwner {
        require(
            state == State.Finished,
            "Presale has not started or already finished"
        );
        state = State.Canceled;
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
        if(totalSold == hardCap) {
            finalize();
        }
        emit TokensPurchased(msg.sender, msg.value);
    }

    function claimTokens() external nonReentrant {
        require(state == State.Finished, "Presale is not finished");
        require(
            claimedAmount[msg.sender] < contributions[msg.sender],
            "Already claimed"
        );

        uint256 claimableAmount = contributions[msg.sender] * tokenPrice;
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

    function burnRemainingTokens() external onlyOwner {
        uint256 burnAmount = getRemainingTokensToHardCap();
        require(burnAmount > 0, "No remaining tokens to burn");
        token.safeTransfer(address(0), burnAmount);
    }

    function refundLaunchpadTokenToOwner() external onlyOwner {
        uint256 refundAmount = getRemainingTokensToHardCap();
        require(refundAmount > 0, "No remaining tokens for refund");
        token.safeTransfer(owner(), refundAmount);
    }

    function getRemainingTokensToHardCap() public view returns (uint256) {
        uint256 soldTokens = totalSold * tokenPrice;
        uint256 maxTokens = hardCap * tokenPrice;

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

    function isFinalized() public view returns(bool){
        return (block.timestamp >= endTime || totalSold >= softCap || totalSold == hardCap);
    }
    function finalize() public payable nonReentrant{
        require(isFinalized(), "can not finalize");
        
    }
}