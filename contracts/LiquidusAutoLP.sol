pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IWETH {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint);

    function allowance(address, address) external view returns (uint);

    receive() external payable;

    function deposit() external payable;

    function withdraw(uint wad) external;

    function totalSupply() external view returns (uint);

    function approve(address guy, uint wad) external returns (bool);

    function transfer(address dst, uint wad) external returns (bool);

    function transferFrom(address src, address dst, uint wad)
    external
    returns (bool);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface ILiquidusFeeEstimation {
    function userFee(address user) external view returns (uint256);
}


pragma experimental ABIEncoderV2;

contract LiquidusAutoLPFarmIn is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => bool) public whitelistRouters;
    mapping(address => bool) public whitelistFromFee;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);

    address public feeWallet;
    address public feeEstimationContract;
    address private _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct SwapCall {
        address _swapToken;     // Token to be swapped
        address _router;        // Address of router contract for performing the swap
        bytes apiData;          // Kyberswap api data, recipient in API request should be this contract!
    }
  
    struct AddLiquidityCall {
        address _router;        // Address of router contract for adding liquidity
        uint256 _amount0Min;    // Minimum amount of toToken0 before transaction reverts (account for fee)
        uint256 _amount1Min;    // Minimum amount of toToken1 before transaction reverts (account for fee)
    }

    struct ZapInCall {
        address[] _inTokens;    // Addresses of input tokens
        uint256[] _inAmounts;   // Amounts of input tokens to swap/deposit
        address[] _toTokens;      // Address of second output tokens
        SwapCall[] swaps;                      // Swaps to execute
        AddLiquidityCall addLiquidityCall;     // Liquidity add call data
        address _lpAddress;      // Address of the LP token
    }

    function zapIn(
        ZapInCall calldata params
    ) payable external nonReentrant whenNotPaused returns (uint256 amountOut0, uint256 amountOut1, uint256 liquidity){
        require(params._inTokens.length <= 2 && params._inTokens.length >=1, "Max 2 input tokens");
        require(params._toTokens.length == 2, "Max and min 2 output tokens");
        require(params._toTokens[0] == IUniswapV2Pair(params._lpAddress).token0() && params._toTokens[1] == IUniswapV2Pair(params._lpAddress).token1() 
            || params._toTokens[0] == IUniswapV2Pair(params._lpAddress).token1() && params._toTokens[1] == IUniswapV2Pair(params._lpAddress).token0(),
            "Error - Mismatch lpAddress and toTokens");
        require(whitelistRouters[params.addLiquidityCall._router], "Error - Liquidity router is not whitelisted");
        require(params.swaps.length < 6, "Error - too many swaps");

        //if one of inputs in _inTokens is ETH -> Swap Eth to WETH, same amount as _inAmount
        for(uint i = 0; i < params._inTokens.length; i++){
            if(params._inTokens[i] == _ETH_ADDRESS_){
                require(msg.value == params._inAmounts[i], "Mismatch ETH amount");
                IWETH(payable(IUniswapV2Router02(params.addLiquidityCall._router).WETH()))
                    .deposit{ value: msg.value }();
            } else {
                IERC20(params._inTokens[i]).safeTransferFrom(msg.sender, address(this), params._inAmounts[i]);
            }
        }

        //swap tokens
        for(uint i = 0; i < params.swaps.length; i++){
            require(whitelistRouters[params.swaps[i]._router], "Swap router not whitelisted");
            _generalApproveMax(params.swaps[i]._swapToken, params.swaps[i]._router, IERC20(params.swaps[i]._swapToken).balanceOf(address(this)));
            (bool success, ) = params.swaps[i]._router.call(params.swaps[i].apiData);
            require(success, "Swap failed");
        }

        // Handle fee, send fee to fee address
        if(!whitelistFromFee[msg.sender]){
            uint256 fee = ILiquidusFeeEstimation(feeEstimationContract).userFee(msg.sender);
            // Charge fees based on holdings
            if (fee != 0){
                IERC20(params._toTokens[0]).safeTransfer(feeWallet, IERC20(params._toTokens[0]).balanceOf(address(this)).mul(fee).div(10000));
                IERC20(params._toTokens[1]).safeTransfer(feeWallet, IERC20(params._toTokens[1]).balanceOf(address(this)).mul(fee).div(10000));
            }
        }
    
        // Approve to add liquidity
        _generalApproveMax(params._toTokens[0], params.addLiquidityCall._router, IERC20(params._toTokens[0]).balanceOf(address(this)));
        _generalApproveMax(params._toTokens[1], params.addLiquidityCall._router, IERC20(params._toTokens[1]).balanceOf(address(this)));

        // Add liquidity, mint lp token to user
        (amountOut0, amountOut1, liquidity) = IUniswapV2Router02(params.addLiquidityCall._router).addLiquidity(
            params._toTokens[0],
            params._toTokens[1],
            IERC20(params._toTokens[0]).balanceOf(address(this)),
            IERC20(params._toTokens[1]).balanceOf(address(this)),
            params.addLiquidityCall._amount0Min,
            params.addLiquidityCall._amount1Min,
            msg.sender,
            uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
        );

        // Keep residual (if any)
        uint256 balance0 = IERC20(params._toTokens[0]).balanceOf(address(this));
        uint256 balance1 = IERC20(params._toTokens[1]).balanceOf(address(this));
        if (balance0 > 0) {IERC20(params._toTokens[0]).safeTransfer(feeWallet, balance0);}
        if (balance1 > 0) {IERC20(params._toTokens[1]).safeTransfer(feeWallet, balance1);}
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

    function setFees(address _feeWallet, address _feeEstimationContract) public onlyOwner {
        feeWallet = _feeWallet;
        feeEstimationContract = _feeEstimationContract;
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function addWhitelistFromFee(address _account) public onlyOwner {
        whitelistFromFee[_account] = true;
    }

    function removeWhitelistFromFee(address _account) public onlyOwner {
        whitelistFromFee[_account] = false;
    }

    function addWhitelistRouters(address _router) public onlyOwner {
        whitelistRouters[_router] = true;
    }

    function removeWhitelistRouters(address _router) public onlyOwner {
        whitelistRouters[_router] = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}
}


contract LiquidusAutoLPFarmOut is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => bool) public whitelistRouters;
    mapping(address => bool) public whitelistFromFee;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);

    address public feeWallet;
    address public feeEstimationContract;
    address private _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct SwapCall {
        address _swapToken;     // Token to be swapped
        address _router;        // Address of router contract for performing the swap
        bytes apiData;          // Kyberswap api data, recipient in API request should be this contract!
    }
  
    struct AddLiquidityCall {
        address _router;        // Address of router contract for adding liquidity
        uint256 _amount0Min;    //  Minimum amount of toToken0 before transaction reverts
        uint256 _amount1Min;    // Minimum amount of toToken1 before transaction reverts
    }

    struct ZapOutCall {
        address[] _toTokens;                // Addresses of output tokens
        SwapCall[] swaps;                   // Swaps to execute 
        AddLiquidityCall addLiquidityCall;  // Liquidity add call data
        uint256 _liquidity;                 //amount of lp to burn (withdraw)
        address _lpAddress;                 // Address of the lp token
    }

    function zapOut(
        ZapOutCall calldata params
    ) payable external nonReentrant whenNotPaused {
        require(params._toTokens.length <= 2 && params._toTokens.length >=1, "Max 2 output tokens");
        require(params.swaps.length < 6, "Error - too many swaps");
        
        // Transfer lp token to contract
        IERC20(params._lpAddress).safeTransferFrom(msg.sender, address(this), params._liquidity);

        // Remove liquidity
        require(whitelistRouters[params.addLiquidityCall._router], "Error - Liquidity router is not whitelisted");
        _generalApproveMax(params._lpAddress, params.addLiquidityCall._router, IERC20(params._lpAddress).balanceOf(address(this)));
        address token0 = IUniswapV2Pair(params._lpAddress).token0();
        address token1 = IUniswapV2Pair(params._lpAddress).token1();
        IUniswapV2Router02(params.addLiquidityCall._router).removeLiquidity(
            token0,
            token1,
            IUniswapV2Pair(params._lpAddress).balanceOf(address(this)),
            params.addLiquidityCall._amount0Min,
            params.addLiquidityCall._amount1Min,
            address(this),
            uint256(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
        );

        //swap tokens
        for(uint i = 0; i < params.swaps.length; i++){
            require(whitelistRouters[params.swaps[i]._router], "Swap router not whitelisted");
            _generalApproveMax(params.swaps[i]._swapToken, params.swaps[i]._router, IERC20(params.swaps[i]._swapToken).balanceOf(address(this)));
            (bool success, ) = params.swaps[i]._router.call(params.swaps[i].apiData);
            require(success, "Swap failed");
        }

        // Handle fee, send fee to fee address
        if(!whitelistFromFee[msg.sender]){
            uint256 fee = ILiquidusFeeEstimation(feeEstimationContract).userFee(msg.sender);
            // Charge fees based on holdings
            if (fee != 0){
                if(params._toTokens.length == 2) {
                    _generalTransfer(params._toTokens[0], payable(feeWallet), _generalBalanceOf(params._toTokens[0], address(this)).mul(fee).div(10000));
                    _generalTransfer(params._toTokens[1], payable(feeWallet), _generalBalanceOf(params._toTokens[1], address(this)).mul(fee).div(10000));
                } else {
                    _generalTransfer(params._toTokens[0], payable(feeWallet), _generalBalanceOf(params._toTokens[0], address(this)).mul(fee).div(10000));
                }
            }
        }

        // Send toTokens to user
        if(params._toTokens.length == 2) {
            _generalTransfer(params._toTokens[0], payable(msg.sender), _generalBalanceOf(params._toTokens[0], address(this)));
            _generalTransfer(params._toTokens[1], payable(msg.sender), _generalBalanceOf(params._toTokens[1], address(this)));
        } else {
            _generalTransfer(params._toTokens[0], payable(msg.sender), _generalBalanceOf(params._toTokens[0], address(this)));
        }
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

    function setFees(address _feeWallet, address _feeEstimationContract) public onlyOwner {
        feeWallet = _feeWallet;
        feeEstimationContract = _feeEstimationContract;
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function addWhitelistFromFee(address _account) public onlyOwner {
        whitelistFromFee[_account] = true;
    }

    function removeWhitelistFromFee(address _account) public onlyOwner {
        whitelistFromFee[_account] = false;
    }

    function addWhitelistRouters(address _router) public onlyOwner {
        whitelistRouters[_router] = true;
    }

    function removeWhitelistRouters(address _router) public onlyOwner {
        whitelistRouters[_router] = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}
}