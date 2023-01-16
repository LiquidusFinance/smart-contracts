// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IStaking {
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
        uint256 lastDepositedAt;
    }
    function userInfo(address account) view external returns (UserInfo memory);
    function lpToken() view external returns (address);
}

interface ILIQNFTs {
    function tokensOfHolder(address _holder) view external returns (uint256[] memory);
}

contract LiquidusFeeEstimation is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event feesChanged(uint256 _feeBronze, uint256 _feeSilver, uint256 _feeGold, uint256 _feeTitan);

    // Name of contract
    string private name;

    // Fee tier thresholds
    uint256 public silver;
    uint256 public gold;
    uint256 public titan;

    // Fee rates per tier
    uint256 public feeBronze;
    uint256 public feeSilver;
    uint256 public feeGold;
    uint256 public feeTitan;

    // Boost percentages per tier (display only)
    uint8 public percentBronze;
    uint8 public percentSilver;
    uint8 public percentGold;
    uint8 public percentTitan;

    // NFT
    bool public useNFT;
    address public NFTcontract;
    mapping(uint256 => uint256) tierOfCollection;

    // fee discount valid contracts (contracts with timelocks only!)
    address[] public lpStakingContracts;
    address[] public tokenStakingContracts;
    mapping(address => bool) public isLpStakingContracts;
    mapping(address => bool) public isTokenStakingContracts;

    address public LIQToken = 0xc7981767f644C7F8e483DAbDc413e8a371b83079; //LIQ token address

    constructor(string memory _name) {
        name = _name;
    }

    function userFee (address user) external view returns (uint256) {
        uint256 holdings = 0;
        uint256 NFTholdings = 0;

        if (useNFT) {
            uint256[] memory tokens = ILIQNFTs(NFTcontract).tokensOfHolder(user);
            uint256 i;
            for (i = 0; i < tokens.length; i++){
                uint256 collection = tokens[i].div(1e6);
                if (tierOfCollection[collection] > NFTholdings){
                    NFTholdings = tierOfCollection[collection];
                }
            }
        }
        
        // Calculate holdings in lp staking pool
        for (uint256 i = 0; i < lpStakingContracts.length; i++) {
            IStaking.UserInfo memory infor = IStaking(lpStakingContracts[i]).userInfo(user);
            if (infor.amount > 0) {
                holdings = holdings.add(infor.amount.mul(getTokenPerLP(IStaking(lpStakingContracts[i]).lpToken())).div(1e18));
            }
        }

        // Calculate holdings in single staking pool
        for (uint256 i = 0; i < tokenStakingContracts.length; i++) {
            IStaking.UserInfo memory infor = IStaking(tokenStakingContracts[i]).userInfo(user);
            holdings = holdings.add(infor.amount);
        }

        if (NFTholdings > holdings) {
            holdings = NFTholdings;
        }

        // Return fee based on holdings
        if (holdings.div(1e18) >= titan){
            return feeTitan;
        } else if (holdings.div(1e18) >= gold && holdings.div(1e18) < titan){
            return feeGold;
        } else if (holdings.div(1e18) >= silver && holdings.div(1e18) < gold){
            return feeSilver;
        } else if (holdings.div(1e18) < silver) {
            return feeBronze;
        }

    }

    function userHoldings (address user) external view returns (uint256) {
        uint256 holdings = 0;
        
        // Calculate holdings in lp staking pool
        for (uint256 i = 0; i < lpStakingContracts.length; i++) {
            IStaking.UserInfo memory infor = IStaking(lpStakingContracts[i]).userInfo(user);
            if (infor.amount > 0) {
                holdings = holdings.add(infor.amount.mul(getTokenPerLP(IStaking(lpStakingContracts[i]).lpToken())).div(1e18));
            }
        }

        // Calculate holdings in single staking pool
        for (uint256 i = 0; i < tokenStakingContracts.length; i++) {
            IStaking.UserInfo memory infor = IStaking(tokenStakingContracts[i]).userInfo(user);
            holdings = holdings.add(infor.amount);
        }

        return holdings;
       
    }

    function setFees(uint256 _feeBronze, uint256 _feeSilver, uint256 _feeGold, uint256 _feeTitan) public onlyOwner {
        require(_feeBronze <= 500, "Error - Fee must be less than 5%");
        require(_feeSilver <= 500, "Error - Fee must be less than 5%");
        require(_feeGold <= 500, "Error - Fee must be less than 5%");
        require(_feeTitan <= 500, "Error - Fee must be less than 5%");
        feeBronze = _feeBronze;
        feeSilver = _feeSilver;
        feeGold = _feeGold;
        feeTitan = _feeTitan;
        emit feesChanged(_feeBronze, _feeSilver, _feeGold, _feeTitan);
    }

    function setTierThresholds(uint256 _silver, uint256 _gold, uint256 _titan) public onlyOwner {
        silver = _silver;
        gold = _gold;
        titan = _titan;
    }

    function setLIQToken(address _LIQToken) public onlyOwner {
        LIQToken = _LIQToken;
    }

    function setBoostPercentage(uint8 _percentBronze, uint8 _percentSilver, uint8 _percentGold, uint8 _percentTitan) public onlyOwner {
        percentBronze = _percentBronze;
        percentSilver = _percentSilver;
        percentGold = _percentGold;
        percentTitan = _percentTitan;
    }

    function setNFT(address _NFTcontract, bool _useNFT) public onlyOwner {
        require(isContract(_NFTcontract), "Must be contract");
        NFTcontract = _NFTcontract;
        useNFT = _useNFT;
    }

    function setCollectionHoldings(uint256 collection, uint256 holdings) public onlyOwner {
        tierOfCollection[collection] = holdings.mul(1e18);
    }

    //Checker for lpStaking and single staking arrays. Source: openzeppelin address library
    function isContract(address _addr) internal view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function getTokenPerLP(address lpContractAddress) public view returns(uint256) {
        uint256 totalLPSupply = IERC20(lpContractAddress).totalSupply();
        uint256 totalLiqInLP = IERC20(LIQToken).balanceOf(lpContractAddress);
        totalLiqInLP = totalLiqInLP.mul(1e18);
        return totalLiqInLP.div(totalLPSupply);
    }

    function addLpStakingContract(address _stakingAddress) public onlyOwner {
        require(isLpStakingContracts[_stakingAddress] == false, "Already in staking list");
        require(isContract(_stakingAddress), "Must be contract");
        isLpStakingContracts[_stakingAddress] = true;
        lpStakingContracts.push(_stakingAddress);
    }

    function removeLpStakingContract(address _stakingAddress) public onlyOwner {
        require(isLpStakingContracts[_stakingAddress] == true, "Not in staking list");
        require(isContract(_stakingAddress), "Must be contract");
        isLpStakingContracts[_stakingAddress] = false;
        for (uint256 i = 0; i < lpStakingContracts.length; i++) {
            if (lpStakingContracts[i] == _stakingAddress) {
                lpStakingContracts[i] = lpStakingContracts[lpStakingContracts.length - 1];
                lpStakingContracts.pop();
                break;
            }
        }
    }

    function addTokenStakingContract(address _stakingAddress) public onlyOwner {
        require(isTokenStakingContracts[_stakingAddress] == false, "Already in staking list");
        require(isContract(_stakingAddress), "Must be contract");
        isTokenStakingContracts[_stakingAddress] = true;
        tokenStakingContracts.push(_stakingAddress);
    }

    function removeTokenStakingContract(address _stakingAddress) public onlyOwner {
        require(isTokenStakingContracts[_stakingAddress] == true, "Not in staking list");
        require(isContract(_stakingAddress), "Must be contract");
        isTokenStakingContracts[_stakingAddress] = false;
        for (uint256 i = 0; i < tokenStakingContracts.length; i++) {
            if (tokenStakingContracts[i] == _stakingAddress) {
                tokenStakingContracts[i] = tokenStakingContracts[tokenStakingContracts.length - 1];
                tokenStakingContracts.pop();
                break;
            }
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}
}