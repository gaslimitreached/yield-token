// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title YieldToken
/// @author @cachemonet
/// @notice ERC20 that yields tokens for every ERC721 deposited. 
/// @dev ERC721 is immutable and provided at construction.
/// @custom:experimental This contract has not been audited.
contract YieldToken is ERC20, IERC721Receiver {
    event Deposit(address indexed owner, uint256 indexed tokenId);
    event Withdraw(address indexed owner, uint256 indexed tokenId);
    event Claim(address indexed onwer, uint256 amount);

    uint256 public constant MAX_SUPPLY = 10_000_000 ether;
    uint256 public constant RATE = 1 ether;

    // Map staked tokens to their owners.
    mapping (uint256 => address) internal stakes;
    // Map owner to count of staked tokens.
    mapping (address => uint256) public count;
    // Map owner to date of last claim.
    mapping (address => uint256) public claimed;
    // Map owner to total yield claimed.
    mapping (address => uint256) public total;

    ERC721 public immutable token;
    constructor(string memory name, string memory symbol, address token_) ERC20(name, symbol) {
        token = ERC721(token_);
    }

    /// @notice Calculate token reward amount.
    /// @return reward amount.
    function rewards() public view returns (uint256) {
        return (count[msg.sender] * (RATE * block.timestamp - claimed[msg.sender])) / 1 days;
    }

    /// @notice Redeem reward amount.
    /// @dev A claim should not exceed the max supply.
    function claim() external {
        uint256 supply = totalSupply();
        uint256 reward = rewards();
        require(0 < reward, "Nothing to claim");
        require(supply < MAX_SUPPLY, "Rewards depleated");
        if (supply + reward > MAX_SUPPLY) {
            reward = (supply + reward) - MAX_SUPPLY;
        }
        unchecked { total[msg.sender] += reward; }
        claimed[msg.sender] = block.timestamp;
        emit Claim(msg.sender, reward);
        _mint(payable(msg.sender), reward);
    }

    /// @notice Accept token in return for yield.
    /// @dev Tokens needs approval for deposit.
    /// @param tokenId The token being deposited.
    /// @return Date of last claim.
    function deposit(uint256 tokenId) external returns (uint256) {
        require(token.getApproved(tokenId) == address(this), "Not approved");
        // Constrained by tokens and token max supply
        unchecked { ++count[msg.sender]; }

        stakes[tokenId] = msg.sender;
        // Only update if this is the first staked token.
        if (claimed[msg.sender] < 1) claimed[msg.sender] = block.timestamp;
        emit Deposit(msg.sender, tokenId);
        token.safeTransferFrom(msg.sender, address(this), tokenId);
        return claimed[msg.sender];
    }
    
    /// @notice Remove deposit
    /// @dev Yield tokens should be claimed beforehand.
    /// @param tokenId The token to withdraw.
    function withdraw(uint256 tokenId) external {
        require(stakes[tokenId] == address(msg.sender), "Not staked");
        unchecked { --count[msg.sender]; }
        // Only reset counter when no other staked tokens.
        if (0 < count[msg.sender]) delete claimed[msg.sender];
        delete stakes[tokenId];
        emit Withdraw(msg.sender, tokenId);
        token.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
