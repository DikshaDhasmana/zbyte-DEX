const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("zbytedex Tests", function () {
    let dex, tokenA, tokenB, LP1, LP2, swapper;

    beforeEach(async function () {
        [LP1, LP2, swapper] = await ethers.getSigners();

        // Deploy Firsttoken and Secondtoken
        const Firsttoken = await ethers.getContractFactory("Firsttoken");
        const Secondtoken = await ethers.getContractFactory("Secondtoken");

        tokenA = await Firsttoken.deploy(ethers.utils.parseUnits("5000", 18));
        tokenB = await Secondtoken.deploy(ethers.utils.parseUnits("700000", 18));

        // Mint tokens
        await tokenA.mint(LP2.address, ethers.utils.parseUnits("7000", 18));
        await tokenA.mint(swapper.address, ethers.utils.parseUnits("1000", 18));
        await tokenB.mint(LP1.address, ethers.utils.parseUnits("500000", 18));

        // Deploy zbytedex
        const zbytedex = await ethers.getContractFactory("zbyteDex");
        dex = await zbytedex.deploy();
    });

    it("Should create a pool", async function () {
        await tokenA.connect(LP1).approve(dex.address, ethers.utils.parseUnits("5000", 18));
        await tokenB.connect(LP1).approve(dex.address, ethers.utils.parseUnits("500000", 18));

        await dex.connect(LP1).createPool(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("5000", 18),
            ethers.utils.parseUnits("500000", 18)
        );

        const { tokenABalance, tokenBBalance } = await dex.getBalances(
            tokenA.address,
            tokenB.address
        );

        const totalLpTokens = await dex.getTotalLpTokens(tokenA.address, tokenB.address);

        expect(tokenABalance).to.equal(ethers.utils.parseUnits("5000", 18));
        expect(tokenBBalance).to.equal(ethers.utils.parseUnits("500000", 18));
        expect(totalLpTokens).to.equal(ethers.utils.parseUnits("10000", 18));
    });

    it("Should add liquidity", async function () {
        await tokenA.connect(LP1).approve(dex.address, ethers.utils.parseUnits("5000", 18));
        await tokenB.connect(LP1).approve(dex.address, ethers.utils.parseUnits("500000", 18));

        await dex.connect(LP1).createPool(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("5000", 18),
            ethers.utils.parseUnits("500000", 18)
        );

        await tokenA.connect(LP2).approve(dex.address, ethers.utils.parseUnits("7000", 18));
        await tokenB.connect(LP2).approve(dex.address, ethers.utils.parseUnits("700000", 18));

        await expect(
            dex.connect(LP2).addLiquidity(
                tokenA.address,
                tokenB.address,
                ethers.utils.parseUnits("7000", 18),
                ethers.utils.parseUnits("500000", 18)
            )
        ).to.be.revertedWith("must add liquidity at the current spot price");

        await dex.connect(LP2).addLiquidity(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("7000", 18),
            ethers.utils.parseUnits("700000", 18)
        );

        const { tokenABalance, tokenBBalance } = await dex.getBalances(
            tokenA.address,
            tokenB.address
        );

        const totalLpTokens = await dex.getTotalLpTokens(tokenA.address, tokenB.address);
        const lp1Balance = await dex.getLpBalance(LP1.address, tokenA.address, tokenB.address);
        const lp2Balance = await dex.getLpBalance(LP2.address, tokenA.address, tokenB.address);

        expect(tokenABalance).to.equal(ethers.utils.parseUnits("12000", 18));
        expect(tokenBBalance).to.equal(ethers.utils.parseUnits("1200000", 18));
        expect(totalLpTokens).to.equal(ethers.utils.parseUnits("24000", 18));
        expect(lp2Balance).to.be.above(ethers.utils.parseUnits("10000", 18));
        expect(lp1Balance).to.equal(ethers.utils.parseUnits("10000", 18));
    });

    it("Should swap tokens", async function () {
        await tokenA.connect(LP1).approve(dex.address, ethers.utils.parseUnits("5000", 18));
        await tokenB.connect(LP1).approve(dex.address, ethers.utils.parseUnits("500000", 18));

        await dex.connect(LP1).createPool(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("5000", 18),
            ethers.utils.parseUnits("500000", 18)
        );

        await tokenA.connect(LP1).approve(dex.address, ethers.utils.parseUnits("5000", 18));
        await tokenB.connect(LP1).approve(dex.address, ethers.utils.parseUnits("500000", 18));

        await dex.connect(LP1).addLiquidity(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("5000", 18),
            ethers.utils.parseUnits("500000", 18)
        );

        await tokenA.connect(swapper).approve(dex.address, ethers.utils.parseUnits("1000", 18));
        await dex.connect(swapper).swap(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("1000", 18)
        );

        const { tokenABalance, tokenBBalance } = await dex.getBalances(
            tokenA.address,
            tokenB.address
        );

        expect(tokenABalance).to.equal(ethers.utils.parseUnits("6000", 18));
        expect(tokenBBalance).to.be.below(ethers.utils.parseUnits("1200000", 18));
        expect(await tokenA.balanceOf(swapper)).to.equal(ethers.utils.parseUnits("0", 18));
        expect(await tokenB.balanceOf(swapper)).to.be.above(ethers.utils.parseUnits("0", 18));
    });

    it("Should remove liquidity", async function () {
        await tokenA.connect(LP1).approve(dex.address, ethers.utils.parseUnits("5000", 18));
        await tokenB.connect(LP1).approve(dex.address, ethers.utils.parseUnits("500000", 18));

        await dex.connect(LP1).createPool(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("5000", 18),
            ethers.utils.parseUnits("500000", 18)
        );

        await tokenA.connect(LP1).approve(dex.address, ethers.utils.parseUnits("5000", 18));
        await tokenB.connect(LP1).approve(dex.address, ethers.utils.parseUnits("500000", 18));

        await dex.connect(LP1).addLiquidity(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseUnits("5000", 18),
            ethers.utils.parseUnits("500000", 18)
        );

        await dex.connect(LP1).removeLiquidity(
            tokenA.address,
            tokenB.address
        );

        const { tokenABalance, tokenBBalance } = await dex.getBalances(
            tokenA.address,
            tokenB.address
        );

        const totalLpTokens = await dex.getTotalLpTokens(tokenA.address, tokenB.address);
        const lp1Balance = await dex.getLpBalance(LP1.address, tokenA.address, tokenB.address);
        const lp2Balance = await dex.getLpBalance(LP2.address, tokenA.address, tokenB.address);

        expect(tokenABalance).to.be.above(ethers.utils.parseUnits("5000", 18));
        expect(tokenBBalance).to.be.above(ethers.utils.parseUnits("500000", 18));
        expect(totalLpTokens).to.equal(ethers.utils.parseUnits("0", 18));
        expect(lp1Balance).to.equal(ethers.utils.parseUnits("0", 18));
        expect(lp2Balance).to.be.above(ethers.utils.parseUnits("0", 18));
    });
});
