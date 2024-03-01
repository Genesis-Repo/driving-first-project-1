// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    uint256 public feePercentage;   // Fee percentage to be set by the marketplace owner
    uint256 private constant PERCENTAGE_BASE = 100;

    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
        // New fields for auction feature
        address highestBidder;
        uint256 highestBid;
        uint256 duration; // Duration of the auction in seconds
        uint256 auctionEndTime; // Time when the auction ends
    }

    mapping(address => mapping(uint256 => Listing)) private listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event NFTUnlisted(address indexed seller, uint256 indexed tokenId);
    // New events for auction feature
    event AuctionStarted(address indexed seller, uint256 indexed tokenId, uint256 startingPrice, uint256 duration);
    event AuctionEnded(address indexed seller, address indexed winner, uint256 indexed tokenId, uint256 price);

    constructor() {
        feePercentage = 2;  // Setting the default fee percentage to 2%
    }

    // Function to list an NFT for sale
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        // Similar to the existing listNFT function, without changes for auction
    }

    // Function to start an auction for an NFT
    function startAuction(address nftContract, uint256 tokenId, uint256 startingPrice, uint256 duration) external {
        require(startingPrice > 0, "Starting price must be greater than zero");
        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        uint256 auctionEndTime = block.timestamp + duration;
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: startingPrice,
            isActive: true,
            highestBidder: address(0),
            highestBid: startingPrice,
            duration: duration,
            auctionEndTime: auctionEndTime
        });

        emit AuctionStarted(msg.sender, tokenId, startingPrice, duration);
    }

    // Function for users to place a bid in the auction
    function placeBid(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "Auction is not active");
        require(block.timestamp < listing.auctionEndTime, "Auction has ended");
        require(msg.value > listing.highestBid, "Bid must be higher than current highest bid");

        if (listing.highestBidder != address(0)) {
            payable(listing.highestBidder).transfer(listing.highestBid); // Refund the previous highest bidder
        }

        listing.highestBidder = msg.sender;
        listing.highestBid = msg.value;
    }

    // Function to end the auction and transfer NFT to the highest bidder
    function endAuction(address nftContract, uint256 tokenId) external {
        Listing storage listing = listings[nftContract][tokenId];
        require(listing.isActive, "Auction is not active");
        require(block.timestamp >= listing.auctionEndTime, "Auction has not ended yet");

        IERC721(nftContract).safeTransferFrom(address(this), listing.highestBidder, tokenId);

        // Calculate and transfer the fee to the marketplace owner
        uint256 feeAmount = (listing.highestBid * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = listing.highestBid - feeAmount;
        payable(owner()).transfer(feeAmount); // Transfer fee to marketplace owner

        // Transfer the remaining amount to the seller
        payable(listing.seller).transfer(sellerAmount);

        listing.isActive = false;

        emit AuctionEnded(listing.seller, listing.highestBidder, tokenId, listing.highestBid);
    }

    // Existing functions remain unchanged for changing price and unlisting NFT

    // Function to set the fee percentage by the marketplace owner
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage < PERCENTAGE_BASE, "Fee percentage must be less than 100");

        feePercentage = newFeePercentage;
    }
}