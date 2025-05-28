import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { expect } from "chai";
import { TokenSwapManager, MockERC20, MockUniswapRouter } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ZeroAddress, parseEther, MaxUint256 } from "ethers";

describe("TokenSwapManager", function () {
    async function deployFixture() {
        const [owner, user, other] = await ethers.getSigners();

        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        const tokenA = await MockERC20Factory.deploy("Token A", "TKA", 18);
        const stableToken = await MockERC20Factory.deploy("Stable Token", "USDC", 6);

        const MockRouterFactory = await ethers.getContractFactory("MockUniswapRouter");
        const mockRouter = await MockRouterFactory.deploy();

        const TokenSwapManagerFactory = await ethers.getContractFactory("TokenSwapManager");
        const tokenSwapManager = await TokenSwapManagerFactory.deploy(
            await mockRouter.getAddress(),
            await stableToken.getAddress()
        );

        await tokenA.mint(await user.getAddress(), parseEther("1000"));
        await tokenA.connect(user).approve(await tokenSwapManager.getAddress(), MaxUint256);

        await stableToken.mint(await mockRouter.getAddress(), parseEther("10000"));

        return { tokenSwapManager, mockRouter, tokenA, stableToken, owner, user, other };
    }

    let tokenSwapManager: TokenSwapManager;
    let mockRouter: MockUniswapRouter;
    let tokenA: MockERC20;
    let stableToken: MockERC20;
    let owner: HardhatEthersSigner;
    let user: HardhatEthersSigner;
    let other: HardhatEthersSigner;

    beforeEach(async function () {
        const fixture = await loadFixture(deployFixture);
        tokenSwapManager = fixture.tokenSwapManager;
        mockRouter = fixture.mockRouter;
        tokenA = fixture.tokenA;
        stableToken = fixture.stableToken;
        owner = fixture.owner;
        user = fixture.user;
        other = fixture.other;
    });

    describe("Token Swaps", function () {
        it("should swap tokens successfully", async function () {
            const amountIn = parseEther("100");
            const amountOutMin = parseEther("150"); // Considering 1:2 exchange rate
            
            await expect(tokenSwapManager.connect(user).swapToStable(
                await tokenA.getAddress(),
                amountIn,
                amountOutMin,
                "Test Swap"
            ))
                .to.emit(tokenSwapManager, "TokenSwapped")
                .withArgs(await user.getAddress(), await tokenA.getAddress(), amountIn, amountIn * 2n, "Test Swap");

            // Check token balances
            expect(await tokenA.balanceOf(await mockRouter.getAddress())).to.equal(amountIn);
            expect(await stableToken.balanceOf(await user.getAddress())).to.equal(amountIn * 2n);
        });

        it("should revert when amountIn is zero", async function () {
            await expect(tokenSwapManager.connect(user).swapToStable(
                await tokenA.getAddress(),
                0n,
                0n,
                "Test Swap"
            )).to.be.revertedWithCustomError(tokenSwapManager, "InvalidAmount");
        });        it("should revert when amountOutMin is not met", async function () {
            const amountIn = parseEther("100");
            const amountOutMin = parseEther("250"); // More than the 1:2 exchange rate
            
            await expect(tokenSwapManager.connect(user).swapToStable(
                await tokenA.getAddress(),
                amountIn,
                amountOutMin,
                "Test Swap"
            )).to.be.revertedWith("Insufficient output amount");
        });
    });

    describe("Admin Functions", function () {
        it("should allow owner to set new stable token", async function () {
            const MockERC20Factory = await ethers.getContractFactory("MockERC20");
            const newStableToken = await MockERC20Factory.deploy("New Stable", "USDT", 6);

            await tokenSwapManager.setStableToken(await newStableToken.getAddress());
            expect(await tokenSwapManager.stableToken()).to.equal(await newStableToken.getAddress());
        });

        it("should revert when non-owner tries to set stable token", async function () {
            await expect(tokenSwapManager.connect(other).setStableToken(await stableToken.getAddress()))
                .to.be.revertedWithCustomError(tokenSwapManager, "Unauthorized");
        });
    });
});
