import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("Pool", function () {
  async function deployFixture() {
    let contractAddresses = "";

    // Helper function to log deployment and save address
    const logDeployment = (contractName: string, target: string) => {
      console.log(`${contractName} deployed to ${target}`);
      contractAddresses += `export const ${contractName}Address = '${target}';\n`;
    };

    // Get the signers (accounts)
    const [user, otherUser] = await hre.ethers.getSigners();

    const ABCToken = await hre.ethers.getContractFactory("ABCToken");
    const abcToken = await ABCToken.deploy(100000000);
    logDeployment("ABCToken", abcToken.target.toString());

    const DEFToken = await hre.ethers.getContractFactory("DEFToken");
    const defToken = await DEFToken.deploy(50000000);
    logDeployment("DEFToken", abcToken.target.toString());

    const Pool = await hre.ethers.getContractFactory("Pool");
    const pool = await Pool.deploy(abcToken, defToken);
    logDeployment("Pool", pool.target.toString());

    return { pool, abcToken, defToken, user, otherUser };
  }
  it("Should add Liquidity", async function () {
    const { pool, abcToken, defToken, user } = await loadFixture(deployFixture);

    // Fund the test user account
    await abcToken.transfer(user.address, 30000);
    await defToken.transfer(user.address, 30000);

    // Approve the pool contract to spend tokens on behalf of the user
    await abcToken.connect(user).approve(pool, 20000);
    await defToken.connect(user).approve(pool, 15000);

    await pool.connect(user).addLiquidity(20000, 15000);

    const reserves = await pool.getReserves();
    expect(reserves[0]).to.equal(20000);
    expect(reserves[1]).to.equal(15000);

    const lpToken = await pool.balanceOf(user.getAddress());
    expect(lpToken).to.equal(17320);
  });

  it("Should swap TokenABC to TokenDEF and otherwise", async function () {
    const { pool, abcToken, defToken, user, otherUser } = await loadFixture(
      deployFixture
    );

    // Fund the test user account
    await abcToken.transfer(user.address, 30000);
    await defToken.transfer(user.address, 30000);

    // Approve the pool contract to spend tokens on behalf of the user
    await abcToken.connect(user).approve(pool, 30000);
    await defToken.connect(user).approve(pool, 20000);

    await pool.connect(user).addLiquidity(20000, 20000);

    // Fund other user
    const initialAbc = 20000;
    await abcToken.transfer(otherUser.address, initialAbc);
    await abcToken.connect(otherUser).approve(pool, initialAbc);

    // Swap token
    await pool.connect(otherUser).swap(abcToken, initialAbc);

    const expectedDef = 9984;
    expect(await defToken.balanceOf(otherUser)).to.equal(expectedDef);

    // Swap back
    await defToken.connect(otherUser).approve(pool, expectedDef);
    await pool.connect(otherUser).swap(defToken, expectedDef);

    const expectedAbc = 19937;
    expect(await abcToken.balanceOf(otherUser)).to.equal(expectedAbc);
  });

  it("Should remove liquidity", async function () {
    const { pool, abcToken, defToken, user, otherUser } = await loadFixture(
      deployFixture
    );

    // Fund the test user account
    await abcToken.transfer(otherUser.address, 20000);
    await defToken.transfer(otherUser.address, 20000);

    // Approve the pool contract to spend tokens on behalf of the user
    await abcToken.connect(otherUser).approve(pool, 20000);
    await defToken.connect(otherUser).approve(pool, 20000);

    await pool.connect(otherUser).addLiquidity(20000, 20000);
    expect(await abcToken.balanceOf(otherUser)).to.equal(0);
    expect(await defToken.balanceOf(otherUser)).to.equal(0);

    await pool.connect(otherUser).removeLiquidity(20000);
    expect(await abcToken.balanceOf(otherUser)).to.equal(20000);
    expect(await defToken.balanceOf(otherUser)).to.equal(20000);
  });
});
