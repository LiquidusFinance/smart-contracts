// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ILiquidusFeeEstimation {
    function userFee(address user) external view returns (uint256);
}

contract KyberSwapLIQ is Ownable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);

    mapping(address => bool) public whitelistRouter;
    mapping(address => bool) public whitelistFromFee;

    address payable public feeWallet;
    address public feeEstimationContract;
    address constant _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    

    receive() external payable {}

    //Compatible with ETH=>ERC20, ERC20=>ETH
    function useKyberApiData(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        address router,
        bytes memory apiData
    )
        external
        payable
    {
        require(whitelistRouter[router], "Router not whitelisted");

        if (fromToken != _ETH_ADDRESS_) {
            IERC20(fromToken).transferFrom(msg.sender, address(this), fromAmount);
            _generalApproveMax(fromToken, router, fromAmount);
        } else {
            require(fromAmount == msg.value);
        }

        (bool success, ) = router.call{value: fromToken == _ETH_ADDRESS_ ? fromAmount : 0}(apiData);
        require(success, "Swap failed");

        // Handle fee, send fee to fee address
        if(!whitelistFromFee[msg.sender]){
            uint256 fee = ILiquidusFeeEstimation(feeEstimationContract).userFee(msg.sender);
            // Charge fees based on holdings
            if (fee != 0) {
                _generalTransfer(toToken, feeWallet, _generalBalanceOf(toToken, address(this)).mul(fee).div(10000));
            } 
        }

        uint256 returnAmount = _generalBalanceOf(toToken, address(this));

        address payable to = payable(msg.sender);
        _generalTransfer(toToken, to, returnAmount);
    }


    function _generalApproveMax(
        address token,
        address to,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), to);
        if (allowance < amount) {
            if (allowance > 0) {
                IERC20(token).safeApprove(to, 0);
            }
            IERC20(token).safeApprove(to, uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        }
    }

    function _generalTransfer(
        address token,
        address payable to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            if (token == _ETH_ADDRESS_) {
                to.transfer(amount);
            } else {
                IERC20(token).safeTransfer(to, amount);
            }
        }
    }

    function _generalBalanceOf(
        address token, 
        address who
    ) internal view returns (uint256) {
        if (token == _ETH_ADDRESS_ ) {
            return who.balance;
        } else {
            return IERC20(token).balanceOf(who);
        }
    }

    function setFees(address payable _feeWallet, address _feeEstimationContract) public onlyOwner {
        feeWallet = _feeWallet;
        feeEstimationContract = _feeEstimationContract;
    }

    function addWhitelistFromFee(address _account) public onlyOwner {
        whitelistFromFee[_account] = true;
    }

    function removeWhitelistFromFee(address _account) public onlyOwner {
        whitelistFromFee[_account] = false;
    }

    function addWhitelistRouter(address _router) public onlyOwner {
        whitelistRouter[_router] = true;
    }

    function removeWhitelistRouter(address _router) public onlyOwner {
        whitelistRouter[_router] = false;
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }
}