// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LiquidusBoost is Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public rewardToken;

    mapping (address => mapping(uint => bool)) nonceUsed;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);


    function hashEthMsg(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }


    function hash(bytes memory x) public pure returns (bytes32) {
        return keccak256(x);
    }

    function encode(uint256 amount, uint chainId, uint256 nonce, address sender) public pure returns (bytes memory) {
                return abi.encode(
                    amount,
                    chainId,
                    nonce,
                    sender
                );
    }

    function claimBoost (uint256 amount, uint256 nonce, uint8 v, bytes32 r, bytes32 s) public nonReentrant whenNotPaused {
            bytes memory encoded = encode(amount, block.chainid, nonce, msg.sender);
            bytes32 hashed = hash(encoded);
            hashed = hashEthMsg(hashed);
            address recoveredAddress = ecrecover(hashed, v, r, s);
            require(recoveredAddress != address(0) && recoveredAddress == owner(), 'Invalid Signature!');
            require(nonceUsed[msg.sender][nonce] == false, 'Nonce already used!');
            nonceUsed[msg.sender][nonce] = true;
            IERC20(rewardToken).safeTransfer(msg.sender, amount);
    }
    
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) public onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function setRewardToken (address _rewardToken) public onlyOwner {
        rewardToken = _rewardToken;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}
}