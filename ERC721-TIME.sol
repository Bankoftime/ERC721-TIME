// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

interface TIME {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function isUSD(address usd) external view returns (bool);
    function getPrice() external view returns (uint256);
    function Buy(address usd, uint256 amount) external returns (bool);
}

contract ECR721TIME is ERC721Enumerable {
    address public constant Time = 0x13460EAAeaDe9427957F26A570345490b5d7910F;

    uint8 public constant maxMintCount = 100;
    uint8 public totalMintCount = 0;

    uint256 public constant mintPrice = 1 * 10 ** 18;

    mapping(uint8 =&gt; uint256) public depositedTimeOfId;

    uint8 public saleCount;
    uint8[] public saleList;
    mapping(uint256 =&gt; bool) public Listed;
    mapping(uint8 =&gt; uint256) public listingPriceOfTime;

    uint8 public constant depositPercent = 3;
    address public immutable Creator;
    uint8 public constant creatorPercent = 2;
    // For detials regarding TVF, please refer to 
    // https://github.com/Bankoftime/ERC721-TIME?tab=readme-ov-file#time-vision-fund-tvf
    address public constant TVF = 0x8b32E6A77B6dE17B6CC4997214adC68ab304971d;
    uint8 public constant tvfPercent = 1;

    string public baseURI;

    constructor(string memory name, string memory symbol, string memory baseuri, address creator) ERC721(name, symbol) { baseURI = baseuri; Creator = creator; }

    function buyTimeHelper(uint256 timeNeeded, address usd, address buyer) internal {
        uint256 usdNeeded = TIME(Time).getPrice() * timeNeeded / mintPrice;

        IERC20(usd).transferFrom(buyer, address(this), usdNeeded);
        IERC20(usd).approve(Time, usdNeeded);
        TIME(Time).Buy(usd, usdNeeded);
    }

    function Mint(address timeOrUsd) external returns (bool) {
        require(totalMintCount &lt; maxMintCount, 'Mint is complete');

        if(TIME(Time).isUSD(timeOrUsd)) {
            buyTimeHelper(mintPrice, timeOrUsd, msg.sender);
            _mint(msg.sender, ++ totalMintCount);

            depositedTimeOfId[totalMintCount] = mintPrice;
        } else {
            TIME(Time).transferFrom(msg.sender, address(this), mintPrice);
            _mint(msg.sender, ++ totalMintCount);

            depositedTimeOfId[totalMintCount] = mintPrice;
        }

        return true;
    }

    function Burn(uint8 id) external returns (bool) {
        require(ownerOf(id) == msg.sender, 'Not your nft');

        _burn(id);

        TIME(Time).transfer(msg.sender, depositedTimeOfId[id]);

        depositedTimeOfId[id] = 0;

        return true;
    }

    function Listing(uint8 id, uint256 time) external returns (bool) {
        require(ownerOf(id) == msg.sender, 'Not your nft');

        saleCount ++;
        saleList.push(id);
        Listed[id] = true;
        listingPriceOfTime[id] = time;

        return true;
    }

    function updateLists(uint8 id) internal returns (bool) {
        for(uint8 i=0; i&lt;saleList.length ; i++) {
            if(saleList[i] == id) {
                saleList[i] = saleList[saleList.length - 1];
                saleList.pop();
                break;
            }
        }

        saleCount --;
        Listed[id] = false;
        listingPriceOfTime[id] = 0;

        return true;
    }

    function Delisting(uint8 id) external returns (bool) {
        require(ownerOf(id) == msg.sender, 'Not your nft');
        require(Listed[id], 'Not listed');

        updateLists(id);

        return true;
    }

    function Trade(uint8 id, address timeOrUsd) external returns (bool) {
        require(Listed[id], 'Not listed');

        address Seller = ownerOf(id);
        uint256 _listingPriceOfTime = listingPriceOfTime[id];

        if(TIME(Time).isUSD(timeOrUsd)) {
            buyTimeHelper(_listingPriceOfTime, timeOrUsd, msg.sender);

            TIME(Time).transfer(Seller, _listingPriceOfTime * (100 - depositPercent - creatorPercent - tvfPercent) / 100);

            depositedTimeOfId[id] += _listingPriceOfTime * depositPercent / 100;

            TIME(Time).transfer(Creator, _listingPriceOfTime * creatorPercent / 100);
            TIME(Time).transfer(TVF, _listingPriceOfTime * tvfPercent / 100);
        } else {
            TIME(Time).transferFrom(msg.sender, address(this), _listingPriceOfTime);

            TIME(Time).transfer(Seller, _listingPriceOfTime * (100 - depositPercent - creatorPercent - tvfPercent) / 100);

            depositedTimeOfId[id] += _listingPriceOfTime * depositPercent / 100;

            TIME(Time).transfer(Creator, _listingPriceOfTime * creatorPercent / 100);
            TIME(Time).transfer(TVF, _listingPriceOfTime * tvfPercent / 100);
        }

        updateLists(id);

        _update(msg.sender, id, Seller);

        return true;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        return baseURI;
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        require(!Listed[tokenId], 'Freezing');

        address previousOwner = super._update(to, tokenId, auth);

        return previousOwner;
    }
}
