// contracts/Market.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "./SignatureNFT.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "hardhat/console.sol";

contract SignatureMarketPlace is
    ReentrancyGuardUpgradeable,
    ERC1155HolderUpgradeable, OwnableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _itemsIds;
    CountersUpgradeable.Counter private _itemsSold;
    CountersUpgradeable.Counter private _itemsDeleted;



    function initialize() public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        // set the owner of the contract to the one that deployed it
        // owner = payable(msg.sender);
        __ERC1155Holder_init();
    }

   //if toke id exists in this struct, it should return only
   // Token Copies
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable creator;
        uint256 amount;
        address payable seller;
        address payable firstBuyer;
        address payable owner;
        uint256 price;
        bool sold;
        // address[] copyOwners;
    }
    MarketItem[] marketItems;
    mapping(uint256 => MarketItem) private idToMarketItem;
    //mapping of user address to token id to hoodie size in string
    mapping(address =>  mapping(uint256 => string)) private  hoodieSizeForToken;

    //address to tokenId to  hoodies submitted
    mapping(address =>  mapping(uint256 => bool)) private isHoodieSizeSubmittedForTokenId;


    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address creator,
        uint256 amount,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    //mateus

    event ProductUpdated(
      uint256 indexed itemId,
      uint256 indexed oldPrice,
      uint256 indexed newPrice
    );

    event MarketItemDeleted(uint256 itemId);

    event ProductSold(
        uint256 indexed itemId,
        address seller,
        address owner,
        uint256 price
    );

     event ProductListed(
        uint256 indexed itemId
    );

    modifier onlyProductSeller(uint256 id) {
        require(
            idToMarketItem[id].owner == address(0) &&
                idToMarketItem[id].seller == msg.sender, "Only the product can do this operation"
        );
        _;
    }

    modifier onlyItemOwner(uint256 id) {
        require(
            idToMarketItem[id].owner == msg.sender,
            "Only product owner can do this operation"
        );
        _;
        
    }
    modifier onlyFirstBuyer(uint256 id) {
        require(
            idToMarketItem[id].firstBuyer == msg.sender,
            "Only product first Buyer can do this operation"
        );
        _;
    }
       //minting projectTokens admin
    function listPTokens(
        address  nftContract,
        uint256 _BronzePrice,
        uint256 _SilverPrice,
        uint256 _GoldPrice,
        uint256 _PlatinumPrice,
        uint256 _LegendaryPrice 
        ) external  onlyOwner{
        uint Bronze = SignatureNFT(payable(address(nftContract))).Bronze();
        uint Silver = SignatureNFT(payable(address(nftContract))).Silver();
        uint Gold = SignatureNFT(payable(address(nftContract))).Gold();
        uint Platinum = SignatureNFT(payable(address(nftContract))).Platinum();
        uint Legendary = SignatureNFT(payable(address(nftContract))).Legendary();
        
        createMarketItem(nftContract, Bronze,SignatureNFT(payable(address(nftContract))).balanceOf(owner(),Bronze), _BronzePrice);
        createMarketItem(nftContract, Silver,SignatureNFT(payable(address(nftContract))).balanceOf(owner(),Silver), _SilverPrice);
        createMarketItem(nftContract, Gold,SignatureNFT(payable(address(nftContract))).balanceOf(owner(),Gold), _GoldPrice);
        createMarketItem(nftContract, Platinum,SignatureNFT(payable(address(nftContract))).balanceOf(owner(),Platinum), _PlatinumPrice);
        createMarketItem(nftContract, Legendary,SignatureNFT(payable(address(nftContract))).balanceOf(owner(),Legendary), _LegendaryPrice);
    }


       //submit hoodie size for token(only one) id
    function submitHoodieSizeForTokenId(
        address nftContract,
        uint256 tokenId,
        uint256 itemId,
        string memory size
    ) external onlyFirstBuyer(itemId) {
        require(
            tokenId == SignatureNFT(payable(address(nftContract))).Gold() ||
            tokenId == SignatureNFT(payable(address(nftContract))).Platinum() ||
            tokenId == SignatureNFT(payable(address(nftContract))).Legendary(),
            "submitHoodieSize: only Gold, Platinum and Legendary tokens buyers can submit hoodie size"
        );
        require(isHoodieSizeSubmittedForTokenId[msg.sender][tokenId] != true,"you have already submited hoodie size");
        require(
            keccak256(bytes(size)) == keccak256(bytes("Small"))
         || keccak256(bytes(size)) == keccak256(bytes("Medium")) 
         || keccak256(bytes(size)) == keccak256(bytes("Large")) 
         || keccak256(bytes(size)) == keccak256(bytes("XL"))  
         || keccak256(bytes(size)) == keccak256(bytes("XXL")) ,
          "submitHoodieSize: You can only submit Small, Medium, Large , XL and XXL as sized in string"
          );
        hoodieSizeForToken[msg.sender][tokenId] = size;
        isHoodieSizeSubmittedForTokenId[msg.sender][tokenId] = true; 
    }


    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint amount,
        uint256 price
    ) public nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(amount != 0, "token amount should not be equal to zero");

        _itemsIds.increment();
        uint256 itemId = _itemsIds.current();

          idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            amount,
            payable(msg.sender),
            payable(address(0)),
            payable(address(0)),
            price,
            false
            // new address[](0)
        );


         SignatureNFT(payable(address(nftContract))).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            amount,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    function updateMarketItemPrice(uint256 id, uint256 newPrice)
        public 
        payable
        onlyProductSeller(id)
    {
        MarketItem storage item = idToMarketItem[id];
        uint256 oldPrice = item.price;
        item.price = newPrice;

        emit ProductUpdated(id, oldPrice, newPrice);
    }

    function createMarketSale(address nftContract, uint amount, uint256 itemId)
        public
        payable
        nonReentrant returns(uint saleType)
    {

        uint Bronze = SignatureNFT(payable(address(nftContract))).Bronze();
        uint Silver = SignatureNFT(payable(address(nftContract))).Silver();
        uint Gold = SignatureNFT(payable(address(nftContract))).Gold();
        uint Platinum = SignatureNFT(payable(address(nftContract))).Platinum();
        uint Legendary = SignatureNFT(payable(address(nftContract))).Legendary();


        uint256 price = idToMarketItem[itemId].price;
        uint256 finalPrice = price * amount;
        uint256 tokenId = idToMarketItem[itemId].tokenId;

        require(
            msg.value == finalPrice,
            "Please submit the asking price in order to complete the purchase"
        );

       //tranasferring price to seller of the token
        idToMarketItem[itemId].seller.transfer(finalPrice);
        
         SignatureNFT(payable(address(nftContract))).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amount,
            ""
        );

        //add first buyer in strcut if there is 0 adress before
        if(idToMarketItem[itemId].firstBuyer == address(0)){
            idToMarketItem[itemId].firstBuyer = payable(msg.sender);
            }

        if(itemId == Bronze || itemId == Silver || itemId == Gold || itemId == Platinum || itemId == Legendary ){
        //updating current amount of tokens after selling
        idToMarketItem[itemId].amount = getCurrentNFTBalance(nftContract, itemId);
        emit ProductSold(
            idToMarketItem[itemId].itemId,
            idToMarketItem[itemId].seller,
            payable(msg.sender),
            idToMarketItem[itemId].price
        );
        return 0;
        }

        else{
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
    

        emit ProductSold(
            idToMarketItem[itemId].itemId,
            idToMarketItem[itemId].seller,
            payable(msg.sender),
            idToMarketItem[itemId].price
        );

        return 1;

}
}

  function getTokenData(address nftContract, uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return SignatureNFT(payable(address(nftContract))).uri(tokenId);
    }

    function getCurrentNFTBalance(address _nftContract, uint _itemId) public view returns(uint){
       return SignatureNFT(payable(address(_nftContract))).balanceOf(address(this),_itemId);
    }

    //todo
    function putItemToResell(address nftContract, uint256 itemId,uint amount, uint256 newPrice)
        public
        nonReentrant
        onlyItemOwner(itemId)
    {
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(newPrice > 0, "Price must be at least 1 wei");


         SignatureNFT(payable(address(nftContract))).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        
        address payable oldOwner = idToMarketItem[itemId].owner;
        idToMarketItem[itemId].owner = payable(address(0));
        idToMarketItem[itemId].seller = oldOwner;
        idToMarketItem[itemId].price = newPrice;
        idToMarketItem[itemId].sold = false;
        _itemsSold.decrement();

        emit ProductListed(itemId);
    }

    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemsIds.current();
        uint256 unsoldItemCount = _itemsIds.current() - _itemsSold.current() - _itemsDeleted.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (
                
                idToMarketItem[i + 1].sold == false
                
            ) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }


    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemsIds.current();
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
   function fetchSingleItem(uint256 id)
        public
        view
        returns (MarketItem memory)
    {
        return idToMarketItem[id];
    }
    function fetchTokeByID(uint256 _tokenID)
        public
        view
        returns (MarketItem[] memory fetchTokebyID)
    {
        uint256 totalItemCount = _itemsIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].tokenId == _tokenID) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].tokenId == _tokenID) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;

                return items;
            }
        }
    }
        /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemsIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].creator == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].creator == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchUnsolItemsByAddress(address author) public view returns (MarketItem[] memory){
        uint256 totalItemCount = _itemsIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].creator == author && !idToMarketItem[i + 1].sold) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].creator == author && !idToMarketItem[i + 1].sold) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
    function checkTotalTokensListed() public view onlyOwner
        returns (uint256 totalIds, uint256 soldItems)
    {
        return (_itemsIds.current(), _itemsSold.current());
    }
}

