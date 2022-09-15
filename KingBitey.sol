// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract KingBitey is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address public rewardToken;

    uint256 public transactionFee;
    uint256 public burnFee;
    uint256 public liquidityFee;

    uint256 public rewardFeeTotal;
    uint256 public burnFeeTotal;

    address public deadWallet = 0x000000000000000000000000000000000000dEaD;

    mapping(address => bool) public automatedMarketMakerPairs;

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor(
        uint256 totalSupply,
        address _uniswapRouterAddress,
        address _rewardTokenAddress,
        uint256 _transactionFee,
        uint256 _burnFee,
        uint256 _liquidityFee
    ) ERC20("KingBitey", "KINGBITEY") {
        rewardToken = _rewardTokenAddress;
        transactionFee = _transactionFee;
        liquidityFee = _liquidityFee;
        burnFee = _burnFee;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _uniswapRouterAddress
        );
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        _mint(msg.sender, totalSupply);
    }

    receive() external payable {}

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fees = 0;
        uint256 lFee;
        uint256 tFee;
        uint256 bFee;
        if (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]) {
            lFee = amount.mul(liquidityFee).div(100);
            tFee = amount.mul(transactionFee).div(100);
            rewardFeeTotal += tFee;
            bFee = amount.mul(burnFee).div(100);
            burnFeeTotal += bFee;
            fees = lFee.add(lFee).add(tFee).add(bFee);
        }

        amount = amount.sub(fees);

        super._transfer(from, deadWallet, bFee);
        super._transfer(from, address(this), fees.sub(bFee));
        swapAndLiquify(lFee);
        super._transfer(from, to, amount);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens.div(2);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(half, newBalance);
        emit SwapAndLiquify(half, newBalance, half);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForReward(uint256 tokenAmount) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = rewardToken;
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }
}
