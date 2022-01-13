// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract SignatureNFT is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155SupplyUpgradeable {

    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for string;
    CountersUpgradeable.Counter private _tokenIds;


    uint256 public constant Bronze = 1;
    uint256 public constant Silver = 2;
    uint256 public constant Gold = 3;
    uint256 public constant Platinum = 4;
    uint256 public constant Legendary = 5;
    address marketPlaceAddress;
    //how many tokens a user can mint, not admin
    uint minterCopyAmount;
    event MarketplaceAddress(address);
    mapping (uint256 => string) private _uris;

    event Received(address, uint256);

    function initialize(address _marketPlaceAddress) initializer public {
        __ERC1155_init("https://gateway.pinata.cloud/ipfs/QmeH8CLgu1xEWjeiVmyNV4McPEbfwCSRAbb3qaTgFVQXNk/{id}.json");
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();
        createToken(owner(),200);
        createToken(owner(),100);
        createToken(owner(),50);
        createToken(owner(),15);
        createToken(owner(),1);
        setTokenURIsForPtokens();
        minterCopyAmount = 1;
        marketPlaceAddress = _marketPlaceAddress;
        setApprovalForAll(marketPlaceAddress,true);
    }
    // a function for minting tokens
    //admin can mint a token with multiple copies
    //other user can only mint one token, unique token
     function createToken(address _to, uint _copies) public returns (uint) {
         _tokenIds.increment();
         if (msg.sender == owner()) {
         uint256 newItemId = _tokenIds.current();
             _mint(_to, newItemId, _copies, "");
            setApprovalForAll(marketPlaceAddress,true);
             return newItemId;
         }
         else{
             require(msg.sender != owner(),"error: admin cannot mint this");
            uint256 newItemId = _tokenIds.current();
            _mint(_to, newItemId, minterCopyAmount, "");
            setApprovalForAll(marketPlaceAddress,true);
            return newItemId;
         }
    }

    //setting token URI's for cards
    function setTokenURIsForPtokens() private onlyOwner {
        _uris[Bronze] = "https://gateway.pinata.cloud/ipfs/QmeH8CLgu1xEWjeiVmyNV4McPEbfwCSRAbb3qaTgFVQXNk/0.json";
        _uris[Silver] = "https://gateway.pinata.cloud/ipfs/QmeH8CLgu1xEWjeiVmyNV4McPEbfwCSRAbb3qaTgFVQXNk/1.json";
        _uris[Gold] = "https://gateway.pinata.cloud/ipfs/QmeH8CLgu1xEWjeiVmyNV4McPEbfwCSRAbb3qaTgFVQXNk/2.json";
        _uris[Platinum] = "https://gateway.pinata.cloud/ipfs/QmeH8CLgu1xEWjeiVmyNV4McPEbfwCSRAbb3qaTgFVQXNk/3.json";
        _uris[Legendary] = "https://gateway.pinata.cloud/ipfs/QmeH8CLgu1xEWjeiVmyNV4McPEbfwCSRAbb3qaTgFVQXNk/4.json";
    }

    //address of the market place to sell token on
    function changeMarketPlaceAddress(address _marketPlaceAddress) public onlyOwner{
        marketPlaceAddress = _marketPlaceAddress;
        emit MarketplaceAddress(marketPlaceAddress);
    }

    function getMarketPlaceAddress() public view returns(address mp){
        return marketPlaceAddress;
    }
    
     function setTokenUri(uint256 _tokenId, string memory newuri) public {
        require(bytes(_uris[_tokenId]).length == 0, "Cannot set uri twice");
        _uris[_tokenId] = newuri;
    }

    function uri(uint256 _tokenId) public view override returns(string memory){
        string memory hexstringtokenID;
        hexstringtokenID =  StringsUpgradeable.toString(_tokenId);
        if (_tokenId < 5) {
            return string( abi.encodePacked( "https://ipfs.io/ipfs/QmbzjepqPb2hCy7NV7RJ5C5V1R3i68RcH5eXN5ZyJkW42t/",hexstringtokenID,".json") );
        } else {
            return(_uris[_tokenId]);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        require(id <=_tokenIds.current(),"");
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
      function setMinterCopyAmount(uint _minterCopyAmount) public onlyOwner {
        minterCopyAmount = _minterCopyAmount;
    }
    function getMinterCopyAmount() public view returns (uint) {
        return minterCopyAmount;
    }
    function checkTotalTokensIdsMinted() public view returns (uint) {
        return _tokenIds.current();
    }
     function getContractAddress() public  view returns (address){
      return marketPlaceAddress;
    }
      receive() external payable {
      emit Received(msg.sender, msg.value);
    }
}
