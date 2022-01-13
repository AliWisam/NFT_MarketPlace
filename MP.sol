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
    OwnableUpgradeable,
    ERC1155HolderUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _itemIds;
    CountersUpgradeable.Counter private _itemsSold;
    CountersUpgradeable.Counter private _itemsDeleted;

    event itemAmountRemaining(uint, uint);
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
    event ProductUpdated(
      uint256 indexed itemId,
      uint256 indexed oldPrice,
      uint256 indexed newPrice
    );
    event ProductSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );
    // event productCopySoldTo(
    //     address copybuyer
    // );
      event ProductListed(
        uint256 indexed itemId
    );

    //if toke id exists in this struct, it should return only
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

    function initialize() public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC1155Holder_init();
    }

        modifier onlyItemOwner(uint256 id) {
        require(
            idToMarketItem[id].owner == msg.sender,
            "Only product owner can do this operation"
        );
        _;
    }
        modifier onlyProductSeller(uint256 id) {
        require(
            idToMarketItem[id].owner == address(0) &&
                idToMarketItem[id].seller == msg.sender, "Only the product can do this operation"
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

    /* Places an item for sale on the marketplace
     * for reselling, user should do setApproval for all first
     */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) public nonReentrant {
         _itemIds.increment();
        uint256 itemId = _itemIds.current();
        require(
            SignatureNFT(payable(address(nftContract))).exists(tokenId) !=
                false,
            "createMarketItem: token id not exists"
        );
        require(
            SignatureNFT(payable(address(nftContract))).totalSupply(tokenId) >=
                amount,
            "createMarketItem: wrong amount, totalSupply is less than amount"
        );
        require(
            SignatureNFT(payable(address(nftContract))).balanceOf(
                msg.sender,
                tokenId
            ) >= amount,
            "createMarketItem: not enough tokens"
        );
        require(price > 0, "Price must be at least 1 wei");

        require(amount != 0, "token amount should not be equal to zero");

       

   
         SignatureNFT(payable(address(nftContract))).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );


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
        //To_Do
        // idToMarketItem[itemId].copyOwners.length -1;
        // idToMarketItem[itemId].copyOwners.push(payable(address(0)));

       
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(
        address nftContract,
        uint256 itemId,
        uint256 amount,
        address to
    ) public payable nonReentrant {

        uint Bronze = SignatureNFT(payable(address(nftContract))).Bronze();
        uint Silver = SignatureNFT(payable(address(nftContract))).Silver();
        uint Gold = SignatureNFT(payable(address(nftContract))).Gold();
        uint Platinum = SignatureNFT(payable(address(nftContract))).Platinum();
        uint Legendary = SignatureNFT(payable(address(nftContract))).Legendary();

        uint256 price = idToMarketItem[itemId].price;
        uint256 finalPrice = price * amount;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(
            SignatureNFT(payable(address(nftContract))).balanceOf(
                address(this),
                tokenId
            ) >= amount,
            "createMarketItem: not enough tokens"
        );
        require(
            msg.value == finalPrice,
            "Please submit the asking price in order to complete the purchase"
        );
        //tranasferring price to seller of the token
        idToMarketItem[itemId].seller.transfer(finalPrice);
        //transferring token
        SignatureNFT(payable(address(nftContract))).safeTransferFrom(
            address(this),
            to,
            tokenId,
            amount,
            ""
        );

        //add first buyer in strcut if there is 0 adress before
         if(idToMarketItem[itemId].firstBuyer == address(0)){
                idToMarketItem[itemId].firstBuyer = payable(to);
            }

         if(itemId == Bronze || itemId == Silver || itemId == Gold || itemId == Platinum || itemId == Legendary ){
        //updating current amount of tokens after selling
          idToMarketItem[itemId].amount = SignatureNFT(payable(address(nftContract))).balanceOf(address(this),itemId);

            emit itemAmountRemaining(idToMarketItem[itemId].amount, itemId);

        //   for (uint i=0; i<idToMarketItem[itemId].copyOwners.length; i++) {

        //         if(idToMarketItem[itemId].copyOwners[i] != to){
        //         //storing account address of buyer in owners arrray
        //         idToMarketItem[itemId].copyOwners.push(payable(address(to)));
               
        //         }
                //  emit productCopySoldTo(idToMarketItem[itemId].copyOwners[i]);
        //   }

        //
        _itemsSold.increment();
        //stack too deep
        // emit ProductSold(
        //     idToMarketItem[itemId].itemId,
        //     idToMarketItem[itemId].nftContract,
        //     idToMarketItem[itemId].tokenId,
        //     idToMarketItem[itemId].price
            
           
        // );
            return;
        }

        if(itemId != Bronze || itemId != Silver || itemId != Gold || itemId != Platinum || itemId != Legendary ){
        idToMarketItem[itemId].owner = payable(to);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
        
        //todo , payments for market commision
        // if( idToMarketItem[itemId].seller != owner()){
        //     payable(owner()).transfer(listingPrice);
        // }
        //   emit ProductSold(
        //     idToMarketItem[itemId].itemId,
        //     idToMarketItem[itemId].nftContract,
        //     idToMarketItem[itemId].tokenId,
        //     idToMarketItem[itemId].price
        // );

        }

    }
    //to do, dont use this
    function putItemToResell(address nftContract, uint256 itemId,uint256 amount, uint256 newPrice)
        public
        payable
        nonReentrant
        onlyItemOwner(itemId)
    {
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(newPrice > 0, "Price must be at least 1 wei");
        if(msg.sender == owner()){
        require(msg.value == 0,"Listing Fee is 0 for admin");     
        }
        else{
        // require(
        //     msg.value == listingPrice,
        //     "Price must be equal to listing price"
        // );
        }
        
      
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



    function getTokenData(address nftContract, uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return SignatureNFT(payable(address(nftContract))).uri(tokenId);
    }

    //error here after buying any token from 5 cards
    /* Returns all unsold market items */
      function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current() - _itemsDeleted.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (
                idToMarketItem[i + 1].owner == address(0) &&
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

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
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

    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
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
        uint256 totalItemCount = _itemIds.current();
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
            //proofRead
            /* Returns all unsold market items for user and these are listed on market page */
    function fetchCollections(address _user) public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

         for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].seller == _user && idToMarketItem[i + 1].owner == address(0) 
            ||
                idToMarketItem[i + 1].owner == _user
            ) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].seller == _user && idToMarketItem[i + 1].owner == address(0) 
            || idToMarketItem[i + 1].owner == _user) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }


        function fetchAuthorsCreations(address author) public view returns (MarketItem[] memory){
        uint256 totalItemCount = _itemIds.current();
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

    function checkTotalTokensListed()
        public
        view
        onlyOwner
        returns (uint256 totalIds, uint256 soldItems)
    {
        return (_itemIds.current(), _itemsSold.current());
    }
}
