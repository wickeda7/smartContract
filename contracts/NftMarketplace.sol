// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

// Check out https://github.com/Fantom-foundation/Artion-Contracts/blob/5c90d2bc0401af6fb5abf35b860b762b31dfee02/contracts/FantomMarketplace.sol
// For a full decentralized nft marketplace

error NftMarket__NotListed(uint256 tokenId);
error NftMarket__NoProceeds();
error NftMarket__TransferFailed(address owner, address sender, uint256 price);
error NftMarketplace_PriceMustEqual(uint256 price, uint256 price2);
error NftMarketplace_NotOwner(address owner, address sender);

contract NftMarketplace is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; // total number of items ever created
    Counters.Counter private _itemsSold; // total number of item sold

    bool public isStopped = false;
    uint256 listingPrice = 0.0001 ether; // people have to pay to list their nft
    address payable owner; // Owner of the smart contract

    constructor() ERC721("Metaverse Tokens", "META") {
        owner = payable(msg.sender);
    }

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(address => uint256) private s_proceeds;

    modifier isListed(uint256 tokenId) {
        MarketItem memory listing = idToMarketItem[tokenId];
        if (listing.price <= 0) {
            revert NftMarket__NotListed(tokenId);
        }
        _;
    }
    modifier onlyOwner() {
        // owner is storage variable is set during constructor
        if (msg.sender != owner) {
            revert NftMarketplace_NotOwner(owner, msg.sender);
        }
        _;
    }

    modifier onlyWhenStopped() {
        require(isStopped);
        _;
    }

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );
    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice) public {
        if (idToMarketItem[tokenId].seller != msg.sender) {
            revert NftMarketplace_NotOwner(idToMarketItem[tokenId].seller, msg.sender);
        }

        idToMarketItem[tokenId].price = newPrice;
        emit MarketItemCreated(tokenId, msg.sender, nftAddress, newPrice, false);
    }

    // list item
    function createMarketItem(uint256 tokenId, uint256 price) private nonReentrant {
        require(price > 0, "Price must be greater than zero");
        //require(msg.value == listingPrice, "Price must be equal to listing price");
        if (msg.value != listingPrice) {
            revert NftMarketplace_PriceMustEqual({price: msg.value, price2: listingPrice});
        }
        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender), // seller
            payable(address(this)), //owner
            price,
            false
        );
        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(tokenId, msg.sender, address(this), price, false);
    }

    // Mints a token and list it in the marketplace

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    // BUY Creating the sale of a marketplace item
    // Transfers ownership of the item as well as funds between parties
    function createMarketSale(uint256 tokenId) public payable nonReentrant {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        //s_proceeds[seller] += msg.value;
        //delete (idToMarketItem[tokenId]);
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listingPrice);
        payable(seller).transfer(msg.value);
        emit ItemBought(msg.sender, address(this), tokenId, price);
    }

    // Returns all unsold market items

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Returns only itens that a user has purchased
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Returns only itens that a user has listed
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1; // it will work as the tokenId
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Allows user to resell a token they have purchased
    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idToMarketItem[tokenId].owner == msg.sender,
            "Only item owner can perform this operation"
        );
        require(msg.value == listingPrice, "Price must be equal to listing price!!");
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();
        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(tokenId, msg.sender, address(this), price, false);
    }

    // Allow user to cancel their market listing

    function cancelItemListing(uint256 tokenId) public nonReentrant {
        require(
            idToMarketItem[tokenId].seller == msg.sender,
            "Only item seller can perform this operation!!"
        );
        require(idToMarketItem[tokenId].sold == false, "Only cancel items which are not sold yet");
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].seller = payable(address(0));
        idToMarketItem[tokenId].sold = true;
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);
        // _transfer(address(this), msg.sender, tokenId);
        IERC721(address(this)).safeTransferFrom(address(this), msg.sender, tokenId);
        emit ItemCanceled(msg.sender, address(this), tokenId);
    }

    function withdrawProceeds(
        address seller
    ) external payable onlyWhenStopped onlyOwner nonReentrant {
        uint256 proceeds = s_proceeds[seller];
        if (proceeds <= 0) {
            revert NftMarket__NoProceeds();
        }
        s_proceeds[seller] = 0;
        payable(seller).transfer(proceeds);
        // (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        // if (!success) {
        //     revert NftMarket__TransferFailed(owner, seller, proceeds);
        // }
    }

    /////////////////////
    // Getter Functions //
    /////////////////////

    function getListing(uint256 tokenId) external view returns (MarketItem memory) {
        return idToMarketItem[tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }

    // Returns the listing price of the market
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }
}
